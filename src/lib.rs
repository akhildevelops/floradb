use std::ops::Sub;

use nom::{
    IResult,
    branch::alt,
    bytes::complete::{tag, take_while},
    character::complete::{alpha1, alphanumeric1, char, multispace0},
    combinator::{map, recognize},
    multi::separated_list0,
    sequence::{delimited, pair, preceded, separated_pair},
};

#[derive(Debug, PartialEq)]
pub struct Call<'q> {
    pub identifier: &'q str,
    pub args: Vec<Expression<'q>>,
    pub kwargs: Vec<&'q str>, // Simplified
}

#[derive(Debug, PartialEq)]
pub struct Attribute<'q> {
    pub prefix: Box<Expression<'q>>,
    pub suffix: Box<Expression<'q>>,
}

#[derive(Debug, PartialEq)]
pub struct Subscript<'q> {
    pub identifier: Box<Expression<'q>>,
    pub slice: Box<Expression<'q>>,
}

#[derive(Debug, PartialEq)]
pub enum Expression<'q> {
    Call(Call<'q>),
    Attribute(Attribute<'q>),
    Identifier(&'q str),
    Subscript(Subscript<'q>),
}

#[derive(Debug, PartialEq)]
pub struct Assign<'q> {
    pub identifier: &'q str,
    pub value: Expression<'q>,
}

#[derive(Debug)]
pub enum Variant<'q> {
    Assign(Assign<'q>),
    Expression(Expression<'q>),
}

#[derive(Debug)]
pub struct Root<'q> {
    pub body: Vec<Variant<'q>>,
}

#[cfg(test)]
mod test {
    use std::os::unix::process::parent_id;

    use nom::{
        Input, Parser,
        bits::complete::take,
        bytes::{complete::take_while_m_n, streaming::take_until},
        character::{char, complete},
        combinator::{complete, eof, map_res},
        error::{ErrorKind, ParseError},
        multi::{many0, many1},
        sequence::{self, terminated},
    };

    fn get_kwarg<'q>(input: &'q str) -> IResult<&'q str, (&'q str, Expression<'q>)> {
        Ok(separated_pair(take_until("="), char('='), get_expression).parse(input)?)
    }
    fn get_nokwarg<'q>(input: &'q str) -> IResult<&'q str, Expression<'q>> {
        get_expression(input)
    }
    fn get_arg<'q>(input: &'q str) -> IResult<&'q str, (Option<&'q str>, Expression<'q>)> {
        match get_kwarg(input) {
            Ok((remaining, (key, arg))) => Ok((remaining, (Some(key), arg))),
            Err(_) => get_nokwarg(input).map(|x| (x.0, (None, x.1))),
        }
    }

    fn get_args<'q>(input: &'q str) -> IResult<&'q str, (Vec<Expression<'q>>, Vec<&'q str>)> {
        let (remaining, mut args) = match many0(complete(terminated(
            take_until(","),
            char::<_, nom::error::Error<_>>(','),
        )))
        .parse(input)
        {
            Ok(x) => x,
            Err(_) => ("", vec![input]),
        };
        if remaining.len() > 0 {
            args.push(remaining);
        }
        let mut expressions = vec![];
        let mut keys = vec![];
        for single_arg in args {
            let (_, kv) = get_arg(single_arg)?;
            if let Some(key) = kv.0 {
                expressions.push(kv.1);
                keys.push(key);
            } else {
                expressions.insert(0, kv.1);
                ()
            }
        }
        Ok(("", (expressions, keys)))
    }
    fn take_until_unbalanced(start: char, end: char) -> impl FnMut(&str) -> IResult<&str, &str> {
        move |i| {
            let mut pair_counter = 1;
            let mut char_iter = i.char_indices();
            while let Some((index, element)) = char_iter.next() {
                if element == start {
                    pair_counter += 1;
                }
                if element == end {
                    pair_counter -= 1;
                }
                if pair_counter == 0 {
                    return Ok((&i[index..], &i[..index]));
                }
            }
            Err(nom::Err::Error(nom::error::Error::new(
                i,
                ErrorKind::TakeUntil,
            )))
        }
    }

    // Address below patterns
    // A(hello=kir)
    // A(hello=kir(),bir)
    fn get_pair_braces<'q>(
        input: &'q str,
        start_brace: char,
        end_brace: char,
    ) -> IResult<&'q str, (&'q str, &'q str)> {
        // FIXME: Inefficient
        let start_brace_str = start_brace.to_string();
        let end_brace_str = end_brace.to_string();
        let start_brace_str = start_brace_str.as_str();
        let end_brace_str = end_brace_str.as_str();
        let (remaining, func_name) = take_until(start_brace_str).parse(input)?;
        let (remaining, args) = delimited(
            tag(start_brace_str),
            take_until_unbalanced(start_brace, end_brace),
            tag(end_brace_str),
        )
        .parse(remaining)?;
        Ok((remaining, (func_name, args)))
    }
    fn get_call<'q>(input: &'q str) -> IResult<&'q str, Call<'q>> {
        let (remaining, (func_name, args)) = get_pair_braces(input, '(', ')')?;
        let (_, (args, kwargs)) = get_args(args)?;
        Ok((
            remaining,
            Call {
                identifier: func_name,
                args,
                kwargs,
            },
        ))
    }
    fn get_attribute<'q>(input: &'q str) -> IResult<&'q str, Attribute<'q>> {
        let (remanining, pairs) = separated_pair(
            take_until(".").map_res(|x| get_expression(x)),
            char('.'),
            get_expression,
        )
        .parse(input)?;
        Ok((
            remanining,
            Attribute {
                prefix: Box::new(pairs.0.1),
                suffix: Box::new(pairs.1),
            },
        ))
    }
    fn get_identifier<'q>(input: &'q str) -> IResult<&'q str, &'q str> {
        if input.chars().any(|x| !x.is_alphabetic()) {
            Err(nom::Err::Error(nom::error::Error::from_error_kind(
                input,
                ErrorKind::Alpha,
            )))
        } else {
            Ok(("", input))
        }
    }
    fn get_expression<'q>(input: &'q str) -> IResult<&'q str, Expression<'q>> {
        if let Ok(x) = get_identifier(input) {
            Ok((x.0, Expression::Identifier(x.1)))
        } else if let Ok(x) = get_attribute(input) {
            Ok((x.0, Expression::Attribute(x.1)))
        } else if let Ok(x) = get_call(input) {
            Ok((x.0, Expression::Call(x.1)))
        } else {
            Err(nom::Err::Error(nom::error::Error::from_error_kind(
                input,
                //Fixme: Proper Errors
                ErrorKind::Alpha,
            )))
        }
    }

    fn get_subscript<'q>(input: &'q str) -> IResult<&'q str, Subscript<'q>> {
        let (remaining, (identifier, slice)) = get_pair_braces(input, '[', ']')?;
        Ok((
            remaining,
            Subscript {
                identifier: Box::new(get_expression(identifier)?.1),
                slice: Box::new(get_expression(slice)?.1),
            },
        ))
    }

    fn get_assignment<'q>(input: &'q str) -> IResult<&'q str, Assign<'q>> {
        let pairs = separated_pair(take_until("="), char('='), get_expression).parse(input)?;
        Ok((
            pairs.0,
            Assign {
                identifier: pairs.1.0,
                value: pairs.1.1,
            },
        ))
    }

    use super::*;
    // schema = Schema(column=Tensor().as())
    enum States {
        Unknown,
    }
    #[test]
    fn test_simple_call_wot_args() {
        let some_str = "Schema()";
        let call = get_call(some_str).unwrap();
        assert_eq!(call.0, "");
        assert_eq!(call.1.identifier, &some_str[..6]);
        assert_eq!(call.1.args.len(), 0);
        assert_eq!(call.1.kwargs.len(), 0);
    }
    #[test]
    fn test_simple_call_with_args() {
        let some_str = "Schema(image=Image())";
        let call = get_call(some_str).unwrap();
        assert_eq!(call.0, "");
        assert_eq!(call.1.identifier, &some_str[..6]);
        assert_eq!(call.1.args.len(), 1);
        assert_eq!(call.1.kwargs.len(), 1);
    }
    #[test]
    fn test_attribute_call() {
        let some_str = "db.create(schema)";
        let create_schema = get_expression(some_str).unwrap();
        assert_eq!(create_schema.0, "");
        assert_eq!(
            create_schema.1,
            Expression::Attribute(Attribute {
                prefix: Box::new(Expression::Identifier("db")),
                suffix: Box::new(Expression::Call(Call {
                    identifier: "create",
                    args: vec![Expression::Identifier("schema")],
                    kwargs: vec![]
                }))
            })
        )
    }
    #[test]
    fn test_assign() {
        let some_str = "db=hello";
        let (remaining, assign) = get_assignment(some_str).unwrap();
        assert_eq!(remaining, "");
        assert_eq!(
            assign,
            Assign {
                identifier: "db",
                value: Expression::Identifier("hello")
            }
        );
    }
    #[test]
    fn test_indexing() {
        let some_str = "table[documents]";
        get_subscript(some_str).unwrap();
    }
    #[test]
    fn test_call_args() {
        let some_str = "schema =Schema(column=Tensor(),jisk=jdfj(),);";
        let assignment = get_assignment(some_str).unwrap();
        assert_eq!(assignment.0, ";");
        assert_eq!(assignment.1.identifier, "schema ");
    }

    #[test]
    fn test_unbalanced() {
        let some_test = "columnm=Tensor().as());";
        let (remaining, actual) = take_until_unbalanced('(', ')').parse(some_test).unwrap();
        assert_eq!(");", remaining);
        assert_eq!("columnm=Tensor().as()", actual);
    }
}
