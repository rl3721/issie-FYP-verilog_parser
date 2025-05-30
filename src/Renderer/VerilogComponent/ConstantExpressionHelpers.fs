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

exception UnsupportedConstantExpression of (string*int)



/// Converts a ConstantExpressionT into a ParamExpression.
/// Error checking is built into the function to ensure that the expression is valid and operations are supported.
/// Exceptions are raised for unsupported expressions or operations, and caught by the caller.
let rec ConstantExpressionToParamExpression (expression:ExpressionNode) =
    // printf "Evaluating expression %A\n" expression
    let value = 
        match expression with
        | ConstantExpression constExpr ->
            // printf "Evaluating constant expression %A\n" constExpr
            ConstantExpressionToParamExpression (Expression constExpr.ConstantExpression)
        | Expression expr -> 
            // printf "Evaluating expression of type aa %A\n" expr
            match expr.Type with
            | "additive" ->
                let left = ConstantExpressionToParamExpression (Expression expr.Head.Value)
                let right = ConstantExpressionToParamExpression (Expression expr.Tail.Value)
                match expr.Operator.Value with
                | "+" -> PAdd(left, right)
                | "-" -> PSubtract(left, right)
                | _ -> raise (UnsupportedConstantExpression (sprintf "Unknown operator %s in constant expression" expr.Operator.Value, expr.Location))  //shouldn't happen
            | "multiplicative" ->
                let left = ConstantExpressionToParamExpression (Expression expr.Head.Value)
                let right = ConstantExpressionToParamExpression (Expression expr.Tail.Value)
                match expr.Operator.Value with
                | "*" -> PMultiply(left, right)
                | "/" -> PDivide(left, right)
                | _ -> raise(UnsupportedConstantExpression (sprintf "Unknown operator %s in constant expression" expr.Operator.Value, expr.Location))  //shouldn't happen
            | "unary" ->
                ConstantExpressionToParamExpression (Unary expr.Unary.Value)
            | _ ->
                raise (UnsupportedConstantExpression (sprintf "Unsupported expression type %s in constant expression" expr.Type, expr.Location)) 
        | Unary unary ->
            match unary.Type with
            | "number" -> ConstantExpressionToParamExpression (Number unary.Number.Value)
            | "parenthesis" -> ConstantExpressionToParamExpression (Expression unary.Expression.Value)
            | "primary" -> ConstantExpressionToParamExpression (Primary unary.Primary.Value)
            | _ -> 
                raise (UnsupportedConstantExpression (sprintf "Unsupported unary type %s in constant expression" unary.Type, unary.Location))
        | Primary primary ->
            match primary.PrimaryType with
            | "identifier" ->
                 PParameter (ParamName primary.Primary.Name)
            | _ 
                -> raise (UnsupportedConstantExpression (sprintf "Non single identifier primary type not yet supported, Unsupported primary type %s in constant expression" primary.PrimaryType, primary.Location)) 
        | Number number ->
            match number.NumberType with
            | "all" ->
                match number.Base.Value with
                | "'b" -> System.Convert.ToInt32 (number.AllNumber.Value, 2) |> PInt
                | "'d" -> System.Convert.ToInt32 (number.AllNumber.Value, 10) |> PInt
                | "'h" -> System.Convert.ToInt32 (number.AllNumber.Value, 16) |> PInt
                | "'o" -> System.Convert.ToInt32 (number.AllNumber.Value, 8) |> PInt
                | _ -> raise (UnsupportedConstantExpression (sprintf  "Should not happen, Unfound base %s in constant expression" (Option.defaultValue "" number.Base), number.Location))
            | "unsigned" ->
                number.UnsignedNumber.Value
                |> System.Convert.ToInt32
                |> PInt
            | _ -> 
                raise (UnsupportedConstantExpression (sprintf "unknown number type %s in constant expression" number.NumberType, number.Location)) 
    value

let getParamBindings (items: ItemT list)= 
    let param_bindings = 
        items
        |> List.map(fun item -> Option.get item.ParamDecl)
        |> List.map(fun decl -> decl.ParameterAssignmentList)
        |> List.concat
        |> List.map(fun assignment -> (ParamName assignment.ParameterIdentifier.Name,  (ConstantExpressionToParamExpression (ConstantExpression assignment.ParameterRHS))))
        |> Map.ofList
    param_bindings


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

let ConstantExpressionToInt (expression:ConstantExpressionT) (param_bindings:ParamBindings) =
    let param_expr = ConstantExpressionToParamExpression (ConstantExpression expression)
    let evaluationResult = evaluateParamExpression param_bindings param_expr 
    match evaluationResult with
    | Ok value -> value
    | Error err -> 
        printfn "Error evaluating constant expression: %s %i" err expression.Location
        raise (UnsupportedConstantExpression 
        (sprintf "Error evaluating constant expression: %s" err, expression.Location)) 


let rec renderParamExpression (expr: ParamExpression) (precedence:int) : string =
    // TODO refactor ParamExpression DU and this function to to elminate duplication
    // for multiple binary operators. Could use a local function here, but the better
    // solution would be refactoring the DU.
    match expr with
    | PInt value -> string value
    | PParameter (ParamName name) -> name
    | PAdd (left, right) -> 
        let currentPrecedence = 1;
        if (precedence > currentPrecedence) then
            "(" + (renderParamExpression left currentPrecedence )+ "+" + renderParamExpression right currentPrecedence + ")"
        else renderParamExpression left currentPrecedence + "+" + renderParamExpression right currentPrecedence
    | PSubtract (left, right) -> 
        let currentPrecedence = 1;
        if (precedence > currentPrecedence) then
            "(" + (renderParamExpression left currentPrecedence )+ "-" + renderParamExpression right currentPrecedence + ")"
        else renderParamExpression left currentPrecedence + "-" + renderParamExpression right currentPrecedence
    | PMultiply (left, right) -> 
        let currentPrecedence = 2;
        if (precedence > currentPrecedence) then
            "(" + (renderParamExpression left currentPrecedence )+ "*" + renderParamExpression right currentPrecedence + ")"
        else renderParamExpression left currentPrecedence + "*" + renderParamExpression right currentPrecedence
    | PDivide (left, right) -> 
        let currentPrecedence = 2;
        if (precedence > currentPrecedence) then
            "(" + (renderParamExpression left currentPrecedence )+ "/" + renderParamExpression right currentPrecedence + ")"
        else renderParamExpression left currentPrecedence + "/" + renderParamExpression right currentPrecedence
    | PRemainder (left, right) -> 
        let currentPrecedence = 3;
        "(" + renderParamExpression left currentPrecedence + "%" + renderParamExpression right currentPrecedence + ")" 


let constantExpressionToString (expression:ExpressionNode) (param_bindings:ParamBindings) =
    let param_expr = ConstantExpressionToParamExpression expression
    renderParamExpression param_expr 0

