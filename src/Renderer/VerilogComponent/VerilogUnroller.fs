/// Description: overall verilog is a context senstive language, so we need to keep track of the context
/// The old way of constructing the AST is not suitable for this, and refacrtoring the AST to be more context aware is a lot of work.
/// instead we will unroll the verilog module such that it becomes context free. This makes it item wise flat.
/// This is a temporary solution, and will be replaced with a more robust solution in the future.
module VerilogUnroller

open VerilogTypes
open ErrorCheck
open ConstantExpressionHelpers
open ParameterTypes


// if we encounter an error
exception VerilogUnrollerException of (string*int)

type scope = {
    // an unique id for the scope, used as prefix for declarations in scope
    scope_name: string 

    // the compile time variables in the scope including genvars and parameters
    compile_var_bind: Map<string, int> 
}

type context = {
    Scopes: scope list // the scopes in the context, the first scope is the global scope
}
type context with
    member this.pushScope (scope_name: string) =
        // push a new scope to the context, this is used for generate regions
        {this with Scopes = {scope_name = scope_name; 
                            compile_var_bind = this.Scopes.Head.compile_var_bind} :: this.Scopes}
    member this.popScope () =
        // pop the last scope from the context, this is used for generate regions
        match this.Scopes with
        | [] -> failwith "Shouldn't happen, Cannot pop scope from empty context"
        | _ :: rest -> {this with Scopes = rest} // remove the last scope
    member this.addCompileVar (new_bind:(string*int) list) =
        printf "Adding compile time variable: %A\n" new_bind
        // add a compile time variable to the current scope
        match this.Scopes with
        | [] -> failwith "Shouldn't happen, Cannot add compile var to empty context"
        | head :: rest ->
            let old_bind_list = this.Scopes.Head.compile_var_bind |> Map.toList
            let new_bind_map = Map.ofList (old_bind_list @ new_bind)
            {this with Scopes = {head with compile_var_bind = new_bind_map} :: rest}
    member this.getCompileVar (var_name: string) =
        // get a compile time variable from the current scope
        match this.Scopes with
        | [] -> failwith "Shouldn't happen, Cannot get compile var from empty context"
        | head :: _ ->
            Map.tryFind var_name head.compile_var_bind
            

let evaluateConstantExpression (ctx: context) (expr: ConstantExpressionT)=
    let rec evaluateExpression (expr: ExpressionNode) =
        match expr with
        | ConstantExpression const_expr -> 
            evaluateExpression (Expression const_expr.ConstantExpression)
        | Expression expr ->
            match expr.Type with
            | "additive" -> 
                let headValue = evaluateExpression (Expression expr.Head.Value)
                let tailValue = evaluateExpression (Expression expr.Tail.Value)
                match expr.Operator with
                | Some "+" -> headValue + tailValue
                | Some "-" -> headValue - tailValue
                | _ -> raise (UnsupportedConstantExpression (sprintf "Unsupported operator %s in additive expression" (Option.defaultValue "" expr.Operator), expr.Location))
            | "multiplicative" ->
                let headValue = evaluateExpression (Expression expr.Head.Value)
                let tailValue = evaluateExpression (Expression expr.Tail.Value)
                match expr.Operator with
                | Some "*" -> headValue * tailValue
                | Some "/" -> 
                    if tailValue = 0 then
                        raise (UnsupportedConstantExpression (sprintf "Division by zero in multiplicative expression at %d" expr.Location, expr.Location))
                    else
                        headValue / tailValue
                | _ -> raise (UnsupportedConstantExpression (sprintf "Unsupported operator %s in multiplicative expression" (Option.defaultValue "" expr.Operator), expr.Location))
            | "unary" ->
                evaluateExpression (Unary expr.Unary.Value)
            | _ ->
                raise (UnsupportedConstantExpression (sprintf "Unsupported expression type %s" expr.Type, expr.Location))
        | Unary unary ->
            match unary.Type with
            | "number" -> evaluateExpression (Number unary.Number.Value)
            | "parenthesis" -> evaluateExpression (Expression unary.Expression.Value)
            | "primary" -> evaluateExpression (Primary unary.Primary.Value)
            | _ -> raise (UnsupportedConstantExpression (sprintf "Unsupported unary type %s" unary.Type, unary.Location))
        | Primary primary ->
            match primary.PrimaryType with 
            | "identifier" -> 
                // check if the identifier is a compile time variable
                match ctx.getCompileVar primary.Primary.Name with
                | Some value -> value // return the value of the compile time variable
                | None -> raise (UnsupportedConstantExpression (sprintf "Identifier %s not found in context" primary.Primary.Name, primary.Location))
            | _ ->
                raise (UnsupportedConstantExpression (sprintf "Unsupported primary type %s" primary.PrimaryType, primary.Location))
        | Number number ->
            // if the number is a constant, return its value
            match number.NumberType with
            | "all" -> 
                match number.Base.Value with
                | "'b" -> System.Convert.ToInt32 (number.AllNumber.Value, 2)
                | "'d" -> System.Convert.ToInt32 (number.AllNumber.Value, 10)
                | "'h" -> System.Convert.ToInt32 (number.AllNumber.Value, 16)
                | "'o" -> System.Convert.ToInt32 (number.AllNumber.Value, 8)
                | _ -> raise (UnsupportedConstantExpression (sprintf "Unsupported number base %s" (Option.defaultValue "" number.Base), number.Location))
            | "unsigned" ->
                number.UnsignedNumber.Value |> System.Convert.ToInt32
            | _ -> raise (UnsupportedConstantExpression (sprintf "Unsupported number type %s" number.NumberType, number.Location))
    evaluateExpression (ConstantExpression expr)

let makeConstantExpressionWithNum (num: int, location: int) =
     {
        Type = "constant_expression";
        Location = location;
        ConstantExpression = {
            Type = "unary";
            Location = location;
            Operator = None;
            Head = None;
            Tail = None;
            Unary = Some {
                Type = "number";
                Location = location;
                Primary = None;
                Expression = None;
                Number = Some {
                    Type = "number";
                    NumberType = "all";
                    Bits = Some "32";
                    Base = Some "'d";
                    AllNumber = Some (num |> string);
                    Location = location;
                    UnsignedNumber = None;
                }

            }
        }
    }

let unrollVerilog (verilog: VerilogInput) (linesIndex)  =
    printf "Unrolling Verilog module: %s\n" verilog.Module.ModuleName.Name
    try 

        let item_list = Array.toList (verilog.Module.ModuleItems.ItemList)

        // sort the items by their location, so we can process them in order
        // this might not be necessary, but it helps to keep the order of items consistent
        let item_list = item_list |> List.sortBy (fun item -> item.Location)

        let context = {
            Scopes = [{
                scope_name = "global"
                compile_var_bind = Map.empty // global scope starts with no compile time variables
            }]
        }

        let unrollParamDecl (ctx: context) (paramDecl: ParameterDeclarationT) =
            let param_assignments = paramDecl.ParameterAssignmentList
            let param_bindings = 
                param_assignments
                |> List.map (fun (p_assignment) ->
                    let param_name = p_assignment.ParameterIdentifier.Name
                    let param_value = evaluateConstantExpression ctx p_assignment.ParameterRHS
                    param_name, param_value
                    )
            let new_ctx = 
                ctx.addCompileVar param_bindings // add the parameter bindings to the context
            
            let new_assignments = 
                param_assignments
                |> List.map (fun p_assignment ->
                    let param_name = p_assignment.ParameterIdentifier.Name
                    let param_value = evaluateConstantExpression new_ctx p_assignment.ParameterRHS
                    {p_assignment with ParameterRHS = makeConstantExpressionWithNum (param_value, p_assignment.ParameterRHS.Location) } // replace the RHS with a constant expression
                )
            let new_decl = {paramDecl with ParameterAssignmentList = new_assignments} // clear the parameter assignment list, as it is now unrolled
            new_ctx, new_decl

        let unrollDecl (ctx: context) (item: ItemT) =
            match item.ItemType with
            | "logic_declaration" ->
                let decl = item.Decl.Value
                let new_name_prefix = 
                    match ctx.Scopes.Head.scope_name with
                    | "global" -> "" // global scope has no prefix
                    | string -> string + "_" // prefix the name with the scope name, so we can distinguish between declarations in different scopes
                let new_variables = 
                    decl.Variables
                    |> Array.map (fun var ->
                        let new_name = new_name_prefix + var.Name // prefix the variable name with the scope name
                        {var with Name = new_name} // replace the variable name with the new name
                    )
                let new_range = 
                    match decl.Range with
                    | Some range -> 
                        let new_start = 
                            let start_val = evaluateConstantExpression ctx range.Start
                            makeConstantExpressionWithNum (start_val, range.Start.Location)
                        let new_end =
                            let end_val = evaluateConstantExpression ctx range.End
                            makeConstantExpressionWithNum (end_val, range.End.Location)
                        Some {range with Start = new_start; End = new_end} // replace the range with the new range
                    | None -> None // no range, so we just return None
                ctx, [{item with Decl = Some {decl with Variables = new_variables; Range = new_range}}]
            | _ ->
                ctx, [item] // for all other item types, just return the item as is

        let rec unrollItem (ctx) (item: ItemT) =
            match item.ItemType with
            | "IO_declaration" ->
                // IO declarations are not context sensitive, so we can just return the item as is
                ctx, [item]
            | "parameter_declaration" ->
                let new_ctx, new_decl = unrollParamDecl ctx item.ParamDecl.Value
                // parameter declaration determines the context, but itself is not part of non
                new_ctx, [item]//{item with ItemType = "parameter_declaration"; ParamDecl = Some new_decl} // replace the item with the unrolled declaration
            | "generate_region" ->
                let new_ctx = ctx.pushScope (DrawHelpers.uuid ())
                let region_items = item.GenerateRegion.Value
                let new_region_items = 
                    region_items
                        |> List.fold (fun (ctx, acc) item ->
                            let newCtx, unrolledItem = unrollItem ctx item
                            newCtx, acc @ [unrolledItem]
                        ) (new_ctx, []) // context starts empty
                        |> snd // now we only care about the unrolled items, don't care about the context
                        |> List.concat
                ctx, new_region_items
            | "genvar_declaration" ->
                let genvarId = item.GenVarId.Value
                // let isGenvarAlreadyDeclared = 
                //     match ctx.getCompileVar genvarId.Name with
                //     | Some _ -> true // genvar already exists in the context
                //     | None -> false // genvar does not exist in the context
                // if isGenvarAlreadyDeclared then
                //     raise (VerilogUnrollerException (sprintf "Genvar %s already exists in the context" genvarId.Name, item.Location))
                let new_ctx = 
                    ctx.addCompileVar [(genvarId.Name, 0)] // add the genvar to the context with default value 0
                new_ctx, [] // genvars are not part of the unrolled items, they are just added to the context
            | "logic_declaration" ->
                unrollDecl ctx item
            | _ ->
                // for all other items, we just return the item as is
                ctx, [item] // return the item as is, no need to unroll

        // let rec unrollItems (ctx) (item_list: ItemT list) =

        //     printf "Unrolling items with context: %A\n" ctx
        //     List.fold (fun (genvar_bind, acc) item ->
        //         match item.ItemType with
        //         | "genvar_declaration" ->
        //             // add the genvar to the param_bind context, so it can be used in expressions, default value is 0
        //             let new_param_bind = 
        //                 match item.GenVarId with
        //                 | Some genvarId -> 
        //                     let genvarName = genvarId.Name
        //                     // add the genvar to the param_bind context
        //                     match Map.tryFind (ParamName genvarName) paramBindings with
        //                         | Some _ -> 
        //                             raise (VerilogUnrollerException ((sprintf "Genvar %s already exists in the context" genvarName) , item.Location))
        //                         | None -> Map.add (ParamName genvarName) (PInt 0) genvar_bind
        //                 | None -> genvar_bind
        //             (new_param_bind, acc @ [item])
        //         | "generate_region" ->
        //             let region_context, unrolled_region_items = 
        //                 unrollItems genvar_bind (item.GenerateRegion.Value)
        //             // don't use the context here, just pass it through, any genvars in the region are local
        //             genvar_bind, acc @ unrolled_region_items 
        //         // | "if_generate_construct" ->
        //             // let condition = item.IfGenerateConstruct.Value.Condition
        //             // let conditionValue = ConstantExpressionToInt condition ctx
        //             // let block_context, unrolled_block_items =
        //             //     if conditionValue <> 0 then
        //             //         let if_block = item.IfGenerateConstruct.Value.IfBlock
        //             //         unrollItems ctx if_block
        //             //     else
        //             //         let else_block = item.IfGenerateConstruct.Value.ElseBlock
        //             //         unrollItems ctx else_block
        //             // ctx, acc @ unrolled_block_items


        //         | _ ->
        //             printf "not rolled item: %s\n" item.ItemType
        //             (ctx, acc @ [item])
        //     ) (ctx, []) item_list
        //     // ctx, item_list

        // printf "Starting unrolling of items...\n"
        // let _, unrolledItems = unrollItems paramBindings item_list


        let unrolledItems = 
            item_list
            |> List.fold (fun (ctx, acc) item ->
                let newCtx, unrolledItem = unrollItem ctx item
                newCtx, acc @ unrolledItem
            ) (context, []) // context starts empty
            |> snd // now we only care about the unrolled items, don't care about the context
            |> Array.ofList

        printf "Unrolling completed, creating new Verilog structure...\n"

        let newModuleItems = {verilog.Module.ModuleItems with ItemList = unrolledItems}
        let newModule = {verilog.Module with ModuleItems = newModuleItems}
        let newVerilog = {verilog with Module = newModule}

        Ok newVerilog
    with 
    | UnsupportedConstantExpression msg -> 
        // If an error occurs, we return the error message in the ErrorInfo list.
        // if there is an error in parsing constant expressions, return it
        let extraMsg = [|{Text=sprintf "Unsupported constant expression: %s" (fst msg); Copy=false; Replace=NoReplace}|]
        Error (createErrorMessage linesIndex (snd msg) (fst msg) extraMsg "Constant Expression Parsing Error")