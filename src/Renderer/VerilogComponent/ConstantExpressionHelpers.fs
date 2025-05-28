/// This module provides helpers for evaluating constant expressions in Verilog.
/// It includes function that conversts the expression into a ParamExpression type that can be used in the rest of the renderer.
/// or into a integer value which is used during error checking and rendering of the component.
module ConstantExpressionHelpers

open EEExtensions
open VerilogTypes
open CommonTypes
open DrawHelpers
open Helpers
open NumberHelpers
open VerilogAST
open ParameterTypes


// /////////// Helpers for Expressions ////////////////

type ExpressionNode =
    | ConstantExpression of ConstantExpressionT
    | Expression of ExpressionT
    | Unary of UnaryT
    | Number of NumberT
    | Primary of PrimaryT



let rec ConstantExpressionToParamExpression (expression:ExpressionNode) =
    printf "Evaluating expression %A\n" expression
    let value = 
        match expression with
        | ConstantExpression constExpr ->
            printf "Evaluating constant expression %A\n" constExpr
            ConstantExpressionToParamExpression (Expression constExpr.ConstantExpression)
        | Expression expr -> 
            printf "Evaluating expression of type aa %A\n" expr
            match expr.Type with
            | "additive" ->
                let left = ConstantExpressionToParamExpression (Expression expr.Head.Value)
                let right = ConstantExpressionToParamExpression (Expression expr.Tail.Value)
                match expr.Operator.Value with
                | "+" -> PAdd(left, right)
                | "-" -> PSubtract(left, right)
                | _ -> failwithf "Unknown operator %s in constant expression" expr.Operator.Value //shouldn't happen
            | "multiplicative" ->
                let left = ConstantExpressionToParamExpression (Expression expr.Head.Value)
                let right = ConstantExpressionToParamExpression (Expression expr.Tail.Value)
                match expr.Operator.Value with
                | "*" -> PMultiply(left, right)
                | "/" -> PDivide(left, right)
                | _ -> failwithf "Unknown operator %s in constant expression" expr.Operator.Value //shouldn't happen
            | "unary" ->
                ConstantExpressionToParamExpression (Unary expr.Unary.Value)
            | _ -> // other types of expression not yet supported, should be caught in error checking
                failwithf "Unsupported expression type %s in constant expression" expr.Type
        | Unary unary ->
            match unary.Type with
            | "number" -> ConstantExpressionToParamExpression (Number unary.Number.Value)
            | "parenthesis" -> ConstantExpressionToParamExpression (Expression unary.Expression.Value)
            | "primary" -> ConstantExpressionToParamExpression (Primary unary.Primary.Value)
            | _ ->  // other types of unary not yet supported, should be caught in error checking
                failwithf "Unsupported unary type %s in constant expression" unary.Type 
        | Primary primary ->
            match primary.PrimaryType with
            | "identifier" ->
                 PParameter (ParamName primary.Primary.Name)
            | _ // other types of primary not yet supported, should be caught in error checking
                -> failwithf "Unsupported primary type %s in constant expression" primary.PrimaryType
        | Number number ->
            match number.NumberType with
            | "all" ->
                match number.Base.Value with
                | "'b" -> System.Convert.ToInt32 (number.AllNumber.Value, 2) |> PInt
                | "'d" -> System.Convert.ToInt32 (number.AllNumber.Value, 10) |> PInt
                | "'h" -> System.Convert.ToInt32 (number.AllNumber.Value, 16) |> PInt
                | "'o" -> System.Convert.ToInt32 (number.AllNumber.Value, 8) |> PInt
                | _ -> failwithf "Should not happen Unfound base %s in constant expression" (Option.defaultValue "" number.Base)
            | "unsigned" ->
                number.UnsignedNumber.Value
                |> System.Convert.ToInt32
                |> PInt
            | _ -> 
                failwithf "Should not happen, Unfound number type %s in constant expression" number.NumberType
    value


/// returns the value of a parameter expression given a set of parameter bindings.
/// The simplified value will be either a constant or a linear combination of a constant and a parameter.
/// NB here 'PINT is not a polymorphic type but a type parameter that will be instantiated to int or bigint.
let evaluateParamExpression (paramBindings: ParamBindings) (paramExpr: ParamExpression) : Result<ParamInt, ParamError> =
    // changed the function to be recursive
    let rec recursiveEvaluation (expr: ParamExpression) : ParamExpression =
        match expr with
        | PInt _ -> expr // constant, nothing needs to be changed
        | PParameter name -> 
            match Map.tryFind name paramBindings with
            | Some evaluated -> evaluated
            | None -> PParameter name
        | PAdd (left, right) ->
            match recursiveEvaluation left, recursiveEvaluation right with
            | PInt l, PInt r -> PInt (l+r)
            | newLeft, newRight -> PAdd (newLeft, newRight) // keep as PAdd type
        | PSubtract (left, right) -> 
            match recursiveEvaluation left, recursiveEvaluation right with
            | PInt l, PInt r -> PInt (l-r)
            | newLeft, newRight -> PSubtract (newLeft, newRight) // keep as Psubtract type
        | PMultiply (left, right) ->
            match recursiveEvaluation left, recursiveEvaluation right with
            | PInt l, PInt r -> PInt (l*r)
            | newLeft, newRight -> PMultiply (newLeft, newRight)
        | PDivide (left, right) ->
            match recursiveEvaluation left, recursiveEvaluation right with
            | PInt l, PInt r -> PInt (l/r)
            | newLeft, newRight -> PDivide (newLeft, newRight)
        | PRemainder (left, right) ->
            match recursiveEvaluation left, recursiveEvaluation right with
            | PInt l, PInt r -> PInt (l%r)
            | newLeft, newRight -> PRemainder (newLeft, newRight)
        
    
    let unwrapParamName (ParamName name) = name
    
    let rec collectUnresolved expr =
        match expr with
        | PInt _ -> []
        | PParameter name -> [unwrapParamName name]  // Only collect unresolved parameters
        | PAdd (left, right) 
        | PSubtract (left, right) 
        | PMultiply (left, right)
        | PDivide (left, right) 
        | PRemainder (left, right) ->
            collectUnresolved left @ collectUnresolved right

    match recursiveEvaluation paramExpr with
    | PInt evaluated -> Ok evaluated
    | unresolvedExpr ->
        let unresolvedParams = collectUnresolved unresolvedExpr |> List.distinct
        match unresolvedParams with
        | [] -> Error "Unexpected error: no unresolved parameters found"
        | [singleParam] -> Error $"Parameter {singleParam} could not be resolved"
        | multipleParams -> 
            let paramList = String.concat ", " multipleParams
            Error $"Parameters {paramList} could not be resolved"

let ConstantExpressionToInt (expression:ExpressionNode) (param_bindings:ParamBindings) =
    let param_expr = ConstantExpressionToParamExpression expression
    let evaluationResult = evaluateParamExpression param_bindings param_expr 
    match evaluationResult with
    | Ok value -> value
    | Error err -> 
        printfn "Error evaluating constant expression: %s" err
        failwithf "Error evaluating constant expression: %s" err //TODO: handle this more gracefully in the future

