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

type DeclarationNameBinding =
    {
        new_names: string list // the new names for the declaration, each name matches a single occurance in unpacked array

        //stores the original dimension of the declaration
        // i.e. a [0:4][0:5] will have dimension [(0,4),(0,5)], singular dimensions are represented as (0,0)
        dimension: (int * int) list 
    }
type scope = {
    // an int to store the scope name, this continue to increase as we push scopes
    scope_name: int 

    // the compile time variables in the scope including genvars and parameters
    compile_var_bind: Map< string, (Result<int,string>) >
    // keep track of the declarations in the scope such names with added prefix can be later resolved


    decl_name_binding: Map<string, DeclarationNameBinding>
}

type context = {
    Scopes: scope list // the scopes in the context, the first scope is the global scope
}
type context with
    member this.pushScope () =
        // push a new scope to the context, this is used for generate regions
        {this with Scopes = {scope_name = this.Scopes.Head.scope_name + 1; 
                            compile_var_bind = this.Scopes.Head.compile_var_bind;
                            decl_name_binding = this.Scopes.Head.decl_name_binding;
                            } :: this.Scopes}

    member this.addCompileVar (new_bind) =
        printf "Adding compile time variable: %A\n" new_bind
        // add a compile time variable to the current scope
        match this.Scopes with
        | [] -> failwith "Shouldn't happen, Cannot add compile var to empty context"
        | head :: rest ->
            let old_bind_list = this.Scopes.Head.compile_var_bind |> Map.toList
            let new_bind_map = Map.ofList (old_bind_list @ new_bind) //new bind comes second so it overrides the old bind
            {this with Scopes = {head with compile_var_bind = new_bind_map} :: rest}
    member this.getCompileVar (var_name: string) =
        // get a compile time variable from the current scope
        match this.Scopes with
        | [] -> failwith "Shouldn't happen, Cannot get compile var from empty context"
        | head :: _ ->
            Map.tryFind var_name head.compile_var_bind
    member this.addDeclNameBinding (new_bind) =
        // add a declaration name binding to the current scope
        match this.Scopes with
        | [] -> failwith "Shouldn't happen, Cannot add decl name binding to empty context"
        | head :: rest ->
            let old_bind_list = this.Scopes.Head.decl_name_binding |> Map.toList
            let new_bind_map = Map.ofList (old_bind_list @ new_bind)
            {this with Scopes = {head with decl_name_binding = new_bind_map} :: rest}

    member this.getDeclName (name: string) (dim_index: int list) =
        // get a declaration name binding from the current scope
        match this.Scopes with
        | [] -> failwith "Shouldn't happen, Cannot get decl name from empty context"
        | head :: _ ->
            Map.tryFind name head.decl_name_binding
            |> Option.bind (fun binding ->
                // check if the dimension index is valid
                if dim_index.Length <> List.length binding.dimension then
                    raise (VerilogUnrollerException (sprintf "Dimension index %A does not match declaration dimension %A" dim_index binding.dimension, 0))
                else
      
                    let shape = 
                        binding.dimension
                        |> List.map (fun (start, end_) -> end_ - start + 1)
                    let zeroed_dim_index =
                        List.mapi (fun i v ->
                            v - (binding.dimension.[i] |> fst)
                        ) dim_index
                    let strides = 
                        shape 
                        |> List.tail 
                        |> List.scan (fun acc v -> acc * v) 1 // calculate the strides for the dimensions
                        |> List.rev 
                        |> List.tail
                    let flat_index = 
                        List.zip zeroed_dim_index strides
                        |> List.sumBy (fun (index, stride) -> index * stride)
                    
                    if flat_index < 0 || flat_index >= List.length binding.new_names then
                        // if the index is out of bounds, return None
                        None
                    else
                        // if the index is valid, return the name at that index
                        Some (binding.new_names.[flat_index])
                    
            )
                
            

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
            | "comparison" ->
                let headValue = evaluateExpression (Expression expr.Head.Value)
                let tailValue = evaluateExpression (Expression expr.Tail.Value)
                match expr.Operator with
                // | Some "==" -> if headValue = tailValue then 1 else 0
                // | Some "!=" -> if headValue <> tailValue then 1 else 0
                | Some "<" -> if headValue < tailValue then 1 else 0
                | Some "<=" -> if headValue <= tailValue then 1 else 0
                | Some ">" -> if headValue > tailValue then 1 else 0
                | Some ">=" -> if headValue >= tailValue then 1 else 0
                | _ -> raise (UnsupportedConstantExpression (sprintf "Unsupported operator %s in comparison expression" (Option.defaultValue "" expr.Operator), expr.Location))
            | "equality" ->
                let headValue = evaluateExpression (Expression expr.Head.Value)
                let tailValue = evaluateExpression (Expression expr.Tail.Value)
                match expr.Operator with
                | Some "==" -> if headValue = tailValue then 1 else 0
                | Some "!=" -> if headValue <> tailValue then 1 else 0
                | _ -> raise (UnsupportedConstantExpression (sprintf "Unsupported operator %s in equality expression" (Option.defaultValue "" expr.Operator), expr.Location))
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
                | Some r -> 
                    match r with
                    | Ok value -> value // return the value of the compile time variable
                    | Error msg -> raise (VerilogUnrollerException (msg, primary.Location))
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
let generateDimPrefix dims =
    List.foldBack
        (fun (lo, hi) acc ->
            if lo > hi then
                raise (VerilogUnrollerException (sprintf "Invalid dimension range (%d, %d)" lo hi, 0))
            List.collect (fun i ->
                List.map (fun suffix ->
                    if suffix = "" then string i else $"{i}_{suffix}"
                ) acc
            ) [lo .. hi]
        )
        dims
        [""]

// printfn "Generating suffixes for dimensions: %A" [(0, 4); (0, 5)]
// printfn "Generated suffixes: %A" (generateSuffixes [(0, 4); (0, 5)])

let unrollVerilog (verilog: VerilogInput) (linesIndex)  =
    printf "Unrolling Verilog module: %s\n" verilog.Module.ModuleName.Name
    try 

        let item_list = Array.toList (verilog.Module.ModuleItems.ItemList)

        // sort the items by their location, so we can process them in order
        // this might not be necessary, but it helps to keep the order of items consistent
        let item_list = item_list |> List.sortBy (fun item -> item.Location)

        let context = {
            Scopes = [{
                scope_name = 0
                compile_var_bind = Map.empty // global scope starts with no compile time variables
                decl_name_binding = Map.empty // global scope starts with no declaration name bindings
            }]
        }

        let unrollParamDecl (ctx: context) (paramDecl: ParameterDeclarationT) =
            let param_assignments = paramDecl.ParameterAssignmentList
            let param_bindings = 
                param_assignments
                |> List.map (fun (p_assignment) ->
                    let param_name = p_assignment.ParameterIdentifier.Name
                    let param_value = evaluateConstantExpression ctx p_assignment.ParameterRHS
                    param_name, Ok param_value
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
                let scope_prefix = //prefix based on the scope name, so we can distinguish between declarations in different scopes
                    match ctx.Scopes.Head.scope_name with
                    | 0 -> "_global_" 
                    | other_val -> "_scoped" + string other_val + "_"

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

                let new_decl = 
                    decl.Variables
                    |> Array.toList
                    |> List.collect (fun v ->
                        let Location = 
                            match v with
                            | Identifier var_id -> var_id.Location // if the variable is a single identifier, we just use its location
                            | IdentifierDimension var_dim -> var_dim.Identifier.Location // if the variable is an unpacked array, we use the identifier location
                        let new_decl_names = 
                            match v with
                            | Identifier var_id -> [scope_prefix+ var_id.Name] // if the variable is a single identifier, we just add a prefix to the name
                            | IdentifierDimension var_dim -> 
                                // if the variable is an unpacked array, we need to create a prefix for each dimension
                                let dim_prefix = 
                                    var_dim.Dimension
                                    |> List.map (fun (start, end_) ->
                                        let start_val = evaluateConstantExpression ctx start
                                        let end_val = evaluateConstantExpression ctx end_
                                        (start_val, end_val)
                                    )
                                    |> generateDimPrefix
                                    |> List.map (fun dp ->
                                        scope_prefix + dp + "_" + var_dim.Identifier.Name
                                    )
                                dim_prefix
                        let new_variable =
                            new_decl_names
                            |> List.map (fun new_name ->
                                Identifier {
                                    Name = new_name; 
                                    Location = Location
                                }
                            )
                        new_variable
                        |> List.map (fun var ->
                            {decl with
                                Range = new_range;
                                Variables = [var] |> List.toArray
                            }
                        )
                    )
                let new_item = 
                    new_decl
                    |> List.map (fun d ->
                        {item with ItemType = "logic_declaration"; Decl = Some d} // replace the item with the unrolled declaration
                        
                    )

                let new_variables_bindings = 
                    decl.Variables
                    |> Array.toList
                    |> List.collect (fun var ->
                        match var with
                        | Identifier var_id ->
                            let var_name = var_id.Name
                            let new_name = scope_prefix + var_name
                            let dim = [(0,0)]
                            let decl_name_binding = 
                                {new_names = [new_name]; dimension = dim} // create a new declaration name binding with the new name and dimension
                            let var_bind = (var_name, decl_name_binding)
                            [var_bind]
                        | IdentifierDimension var_dim ->
                            let var_name = var_dim.Identifier.Name
                            let new_names = 
                                var_dim.Dimension
                                |> List.map (fun (start, end_) ->
                                    let start_val = evaluateConstantExpression ctx start
                                    let end_val = evaluateConstantExpression ctx end_
                                    generateDimPrefix [(start_val, end_val)]
                                    |> List.map (fun dp -> scope_prefix + dp + "_" + var_name)
                                )
                                |> List.concat // flatten the list of lists
                            let dim = 
                                var_dim.Dimension
                                |> List.map (fun (start, end_) ->
                                    let start_val = evaluateConstantExpression ctx start
                                    let end_val = evaluateConstantExpression ctx end_
                                    (start_val, end_val)
                                )
                            let decl_name_binding = 
                                {new_names = new_names; dimension = dim} // create a new declaration name binding with the new names and dimension
                            let var_bind = (var_name, decl_name_binding)
                            [var_bind]
                    )
                let new_ctx = 
                    ctx.addDeclNameBinding (
                        new_variables_bindings 
                        ) // add the new variable bindings to the context

                new_ctx, new_item // return the new context and the new item list

                // ctx, [item]
            | _ ->
                ctx, [item] // for all other item types, just return the item as is

        let rec unrollExpression (ctx: context) (expr: ExpressionT) =
            match expr.Unary with 
            | None ->
                match expr.Head, expr.Tail with
                | Some head, Some tail ->
                    let new_head = unrollExpression ctx head
                    let new_tail = unrollExpression ctx tail
                    {expr with Head = Some new_head; Tail = Some new_tail}
                | Some head, None ->
                    let new_head = unrollExpression ctx head
                    {expr with Head = Some new_head; Tail = None}
                | None, Some tail ->
                    let new_tail = unrollExpression ctx tail
                    {expr with Head = None; Tail = Some new_tail}
                | None, None -> expr // no head or tail, just return the expression as is
            | Some unary ->
                let new_unary = unrollUnary ctx unary
                {expr with Unary = Some new_unary}
        and unrollUnary (ctx: context) (unary: UnaryT) =
            match unary.Type with
            | "number" ->
                // for numbers, we just return the unary as is, as it is already a constant expression
                unary
            | "parenthesis" ->
                // for parenthesis, we unroll the expression inside the parenthesis
                let new_expr = unrollExpression ctx unary.Expression.Value
                {unary with Expression = Some new_expr}
            | "primary" -> 
                let primary = unary.Primary.Value
                let expression = unary.Expression
                let new_expression =
                    match expression with
                    | Some expr -> Some (unrollExpression ctx expr)
                    | None -> None
                match ctx.getCompileVar primary.Primary.Name with
                | Some value -> 
                    {
                            Type = "number";
                            Location = primary.Location;
                            Primary = None;
                            Expression = None;
                            Number = Some {
                                Type = "number";
                                NumberType = "all";
                                Bits = Some "32"; // default bits for constant expressions
                                Base = Some "'d"; // default base for constant expressions
                                AllNumber = Some (value |> string); // convert the value to string
                                UnsignedNumber = None;
                                Location = primary.Location;
                            }
                        }
                | None -> 
                    match ctx.getDeclName primary.Primary.Name [0] with
                    | Some new_name ->
                        let new_primary_identifier = {primary.Primary with Name = new_name}
                        let new_width = 
                            match primary.Width with
                            | Some width ->
                                let width_val = evaluateConstantExpression ctx width
                                Some (makeConstantExpressionWithNum (width_val, width.Location)) // replace the width with a constant expression
                            | None -> None // no width, so we just return None
                        let new_start_bit =
                            match primary.BitsStart with
                            | Some bits_start ->
                                let start_val = evaluateConstantExpression ctx bits_start
                                Some (makeConstantExpressionWithNum (start_val, bits_start.Location)) // replace the bits start with a constant expression
                            | None -> None // no bits start, so we just return None
                        let new_end_bit =
                            match primary.BitsEnd with
                            | Some bits_end ->
                                let end_val = evaluateConstantExpression ctx bits_end
                                Some (makeConstantExpressionWithNum (end_val, bits_end.Location)) // replace the bits end with a constant expression
                            | None -> None // no bits end, so we just return None
                        let new_primary = {primary with Primary = new_primary_identifier; Width = new_width; BitsStart = new_start_bit; BitsEnd = new_end_bit}
                        {unary with Primary = Some new_primary; Expression = new_expression} // replace the unary with the new unary
                    | None ->
                        // if the primary is not a compile time variable or a declaration name, we just return the unary as is
                        unary
            | _ -> 
                // for all other unary types, we just return the unary as is
                printf "Unrolling unary: %s\n" unary.Type
                unary // return the unary as is, no need to unroll

        let unrollAssignment (ctx: context) (assignment: AssignmentT) =
            let lhs = assignment.LHS
            let rhs = assignment.RHS
            let unrolled_lhs = 
                let lhs_primary = lhs.Primary
                let new_lhs_primary = 
                    printf "Unrolling LHS primary: %A\n" lhs_primary
                    printf "Current context: %A\n" ctx.Scopes.Head.decl_name_binding
                    match ctx.getDeclName lhs_primary.Name [0] with
                    | Some new_name -> {lhs_primary with Name = new_name} // replace the primary with the new primary from the context
                    | None -> lhs_primary // if not found, just return the original primary
                let new_lhs_bitstart = 
                    match lhs.BitsStart with
                    | Some bits_start ->
                        let start_val = evaluateConstantExpression ctx bits_start
                        Some (makeConstantExpressionWithNum (start_val, bits_start.Location)) // replace the bits start with a constant expression
                    | None -> lhs.BitsStart
                let new_lhs_bitend =
                    match lhs.BitsEnd with
                    | Some bits_end ->
                        let end_val = evaluateConstantExpression ctx bits_end
                        Some (makeConstantExpressionWithNum (end_val, bits_end.Location)) // replace the bits end with a constant expression
                    | None -> lhs.BitsEnd
                let new_lhs_variable_bitselect =
                    match lhs.VariableBitSelect with
                    | Some var_bitselect ->
                        Some (unrollExpression ctx var_bitselect) // unroll the variable bit select expression
                    | None -> lhs.VariableBitSelect
                {lhs with
                    Primary = new_lhs_primary
                    BitsStart = new_lhs_bitstart
                    BitsEnd = new_lhs_bitend
                    VariableBitSelect = new_lhs_variable_bitselect
                }
            let unrolled_rhs = unrollExpression ctx rhs
            {assignment with LHS = unrolled_lhs; RHS = unrolled_rhs} // replace the assignment with the unrolled

        let rec unrollStatement (ctx: context) (statement: StatementT) =
            match statement.StatementType with
            | "conditional" -> 
                let conditional = statement.Conditional.Value
                let if_statement = conditional.IfStatement
                let new_condition = unrollExpression ctx if_statement.Condition
                let new_if_statement = unrollStatement ctx if_statement.Statement
                let new_else_statement =
                    match conditional.ElseStatement with
                    | Some else_statement -> Some (unrollStatement ctx else_statement)
                    | None -> None // no else statement, so we just return None
                let new_conditional = {conditional with IfStatement = {if_statement with Condition = new_condition; Statement = new_if_statement}; ElseStatement = new_else_statement}
                {statement with Conditional = Some new_conditional} // replace the statement with the unrolled conditional
            | "nonblocking_assignment" ->
                let nonblocking_assign = statement.NonBlockingAssign.Value
                let new_assignment = unrollAssignment ctx nonblocking_assign.Assignment
                {statement with NonBlockingAssign = Some {nonblocking_assign with Assignment = new_assignment}} // replace the statement with the unrolled assignment
            | "blocking_assignment" ->
                let blocking_assign = statement.BlockingAssign.Value
                let new_assignment = unrollAssignment ctx blocking_assign.Assignment
                {statement with BlockingAssign = Some {blocking_assign with Assignment = new_assignment}} // replace the statement with the unrolled assignment
            | "seq_block" ->
                let seq_block = statement.SeqBlock.Value
                let new_statements = 
                    seq_block.Statements
                    |> Array.map (fun stmt -> unrollStatement ctx stmt) // unroll each statement in the sequence block
                {statement with SeqBlock = Some {seq_block with Statements = new_statements}} // replace the statement with the unrolled sequence block
            | "case_statement" ->
                let case_statement = statement.CaseStatement.Value
                let new_expression = unrollExpression ctx case_statement.Expression
                let new_case_items = 
                    case_statement.CaseItems
                    |> Array.map (fun item ->
                        let new_item_stat = unrollStatement ctx item.Statement
                        {item with Statement = new_item_stat} // replace the case item statement with the unrolled statement
                    )
                let new_default =
                    match case_statement.Default with
                    | Some default_stmt -> Some (unrollStatement ctx default_stmt) // unroll the default statement if it exists
                    | None -> None // no default statement, so we just return None
                {statement with CaseStatement = Some {case_statement with Expression = new_expression; CaseItems = new_case_items; Default = new_default}} // replace the statement with the unrolled case statement
            | _ ->
                // for all other statement types, we just return the statement as is
                printf "Unrolling statement: %s\n" statement.StatementType
                statement // return the

            // statement

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
                let new_ctx = ctx.pushScope ()
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
                    ctx.addCompileVar [(genvarId.Name, Error (sprintf "Genvar %s not yet assigned" (genvarId.Name)))] // add the genvar to the context with default value 0
                new_ctx, [] // genvars are not part of the unrolled items, they are just added to the context
            | "logic_declaration" ->
                unrollDecl ctx item
            | "statement" -> // this is for continuous assign, named as this from legacy
                let assignment = item.Statement.Value.Assignment
                let new_assignment = unrollAssignment ctx assignment
                let new_cont_assign = {item.Statement.Value with Assignment = new_assignment} // replace the continuous assign with the unrolled assignment
                let new_item = {item with ItemType = "statement"; Statement = Some new_cont_assign} // replace the item with the unrolled assignment
                // for all other items, we just return the item as is
                ctx, [new_item] // return the item as is, no need to unroll
            | "always_construct" ->
                let always_construct = item.AlwaysConstruct.Value
                let statement = always_construct.Statement
                let new_statement = unrollStatement ctx statement
                let new_always_construct = {always_construct with Statement = new_statement} // replace the always construct with the unrolled statement
                let new_item = {item with ItemType = "always_construct"; AlwaysConstruct = Some new_always_construct} // replace the item with the unrolled always construct
                ctx, [new_item] // return the item as is, no need to unroll
            | "module_instantiation" -> //TODO: test this
                let module_instantiation = item.ModuleInstantiation.Value
                let identifier = module_instantiation.Identifier

                // let new_name_prefix = 
                //     match ctx.Scopes.Head.scope_name with
                //     | 0 -> "" // global scope has no prefix
                //     | other_val -> "_" + string other_val + "_" // prefix the name with the scope name, so we can distinguish between declarations in different scopes
                // let new_name = new_name_prefix + identifier.Name // prefix the identifier name with the scope name
                // let new_identifier = {identifier with Name = new_name} // replace the identifier name with the new name
                let new_connections = 
                    module_instantiation.Connections
                    |> Array.map (fun conn ->
                        let conn_primary = conn.Primary
                        let new_identifier = 
                            match ctx.getDeclName conn_primary.Primary.Name [0] with
                            | Some new_name -> {conn_primary.Primary with Name = new_name} // replace the primary with the new primary from the context
                            | None -> conn_primary.Primary // if not found, just return the original primary
                        let new_width =
                            match conn_primary.Width with
                            | Some width ->
                                let width_val = evaluateConstantExpression ctx width
                                Some (makeConstantExpressionWithNum (width_val, width.Location)) // replace the width with a constant expression
                            | None -> None // no width, so we just return None
                        let new_bits_start =
                            match conn_primary.BitsStart with
                            | Some bits_start ->
                                let start_val = evaluateConstantExpression ctx bits_start
                                Some (makeConstantExpressionWithNum (start_val, bits_start.Location)) // replace the bits start with a constant expression
                            | None -> None // no bits start, so we just return None
                        let new_bits_end =
                            match conn_primary.BitsEnd with
                            | Some bits_end ->
                                let end_val = evaluateConstantExpression ctx bits_end
                                Some (makeConstantExpressionWithNum (end_val, bits_end.Location)) // replace the bits end with a constant expression
                            | None -> None // no bits end, so we just return None
                        {conn with Primary = {conn_primary with Primary = new_identifier; Width = new_width; BitsStart = new_bits_start; BitsEnd = new_bits_end}} // replace the connection primary with the new primary
                    )
                let new_param_overrides =
                    match module_instantiation.ParamOverrides with
                    | Some overrides ->
                        overrides
                        |> List.map (fun param_override ->
                            let param_value = evaluateConstantExpression ctx param_override.MinTypExpr
                            {param_override with MinTypExpr = makeConstantExpressionWithNum (param_value, param_override.MinTypExpr.Location)} // replace the parameter override with a constant expression
                
                        )
                        |> Some // wrap the list in Some
                    | None -> None // no parameter overrides, so we just return None
                

                let new_module_instantiation = {module_instantiation with 
                                                    // Identifier = new_identifier
                                                    Connections = new_connections
                                                    ParamOverrides = new_param_overrides
                                                } // replace the module instantiation with the new identifier
                let new_item = {item with ItemType = "module_instantiation"; ModuleInstantiation = Some new_module_instantiation} // replace the item with the unrolled module instantiation

                let new_ctx = ctx //ctx.addDeclNameBinding [(identifier.Name, new_name)] not needed, identifier of module instantiation is not used in expressions, so we don't need to add it to the context
                new_ctx, [new_item] // return the item as is, no need to unroll
            | "if_generate_construct" ->
                let if_generate_construct = item.IfGenerateConstruct.Value
                let condition = if_generate_construct.Condition
                let conditionValue = evaluateConstantExpression ctx condition
                let new_ctx = ctx.pushScope () // push a new scope for the generate region
                let unrolled_block_items =
                    if conditionValue <> 0 then
                        // if the condition is true, we unroll the if block
                        let if_block = if_generate_construct.IfBlock
                        if_block |> List.fold (fun (ctx, acc) item ->
                            let newCtx, unrolledItem = unrollItem ctx item
                            newCtx, acc @ [unrolledItem]
                        ) (new_ctx, [])
                        |> snd // now we only care about the unrolled items, don't care about the context
                    else
                        // if the condition is false, we unroll the else block
                        let else_block = if_generate_construct.ElseBlock
                        else_block |> List.fold (fun (ctx, acc) item ->
                            let newCtx, unrolledItem = unrollItem ctx item
                            newCtx, acc @ [unrolledItem]
                        ) (new_ctx, []) // context starts empty
                        |> snd // now we only care about the unrolled items, don't care about the context
                let new_item = unrolled_block_items |> List.concat
               
                ctx, new_item // return the item as is, no need to unroll
            | "loop_generate_construct" ->
                let loop_generate_construct = item.LoopGenerateConstruct.Value
                let loop_id = loop_generate_construct.LoopId.Name
                let step_id = loop_generate_construct.StepId.Name
                if loop_id <> step_id then
                    raise (VerilogUnrollerException (sprintf "Loop ID %s and Step ID %s must be the same" loop_id step_id, item.Location))

                let rec loopUnrollItems (ctx: context) (unrolled_items: ItemT list) iter_count =
                    let loop_cond_value = evaluateConstantExpression ctx loop_generate_construct.CondExpr
                    if iter_count > 1000 then
                        // prevent infinite loop, if the loop condition is always true
                        raise (VerilogUnrollerException ("Loop unrolling exceeded maximum iterations, prevent infinite loop", item.Location))
                    if (loop_cond_value <> 0) then
                         // if the condition is true, we unroll the block
                        let new_ctx = ctx.pushScope () // push a new scope for the generate region
                        let block_items = loop_generate_construct.Block
                        let unrolled_block_items =
                            block_items |> List.fold (fun (ctx, acc) item ->
                                let newCtx, unrolledItem = unrollItem ctx item
                                newCtx, acc @ [unrolledItem]
                            ) (new_ctx, [])
                            |> snd 
                            |> List.concat // now we only care about the unrolled items, don't care about the context
                        // printf "Unrolling loop block items: %A\n" unrolled_block_items
                        // after unrolling the block, we need to update the loop variable and continue unrolling
                        let step_value = evaluateConstantExpression ctx loop_generate_construct.StepExpr
                        let new_ctx_with_step = new_ctx.addCompileVar [(step_id, Ok step_value)] // add the step value to the context
                        loopUnrollItems new_ctx_with_step (unrolled_items @ unrolled_block_items) (iter_count + 1) // continue unrolling with the updated context and accumulated items

                    else
                        // if the condition is false, we stop unrolling
                        unrolled_items
                       
                let start_value = evaluateConstantExpression ctx loop_generate_construct.StartExpr                      
                let start_ctx = (ctx.pushScope ()).addCompileVar [(loop_id, Ok start_value)]
                let unrolled_items = loopUnrollItems start_ctx [] 0 // start unrolling with the initial context and empty item list

            
                // if loop
                ctx, unrolled_items // return the item as is, no need to unroll
            | _ ->
                // for all other items, we just return the item as is
                printf "Unrolling item: %s\n" item.ItemType
                ctx, [item] // return the item as is, no need to unroll

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