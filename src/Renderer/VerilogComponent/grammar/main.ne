# To compile the .ne file to .js file:
#   1. Install the nearley compiler
#   2. Be in this directory containing the grammar file
#   3. Run: "npx nearleyc ./grammar/main.ne -o ./VerilogGrammar.js"

@include "./lexer.ne"

# Pass your lexer object using the @lexer option:
@lexer lexer

############### GRAMMAR FOR VERILOG 2005 ####################
# This grammar is based on the Verilog 2005 standard
# The grammar is not a complete implementation only a synthesizable subset
# naming are generally based on the Verilog 2005 standard


##################### 1 Source Text ####################
#### 1.1 Library Source Text ####
# Out of scope for project, not implemented

#### 1.2 Verilog Source Text ####
# the starting token of the grammar
SOURCE_TEXT -> MODULE_DECLARATION {%function(d) {return {Type: "source_text", Module: d[0]};} %}

# DESCRIPTION
# token ommitted as non MODULE_DECLARATION token not implemented

# two types of module syntax in verilog, the old style and the new style
# TODO: add support for parameters
MODULE_DECLARATION 
    -> _ %module _ NAME_OF_MODULE _ %lparen _ LIST_OF_PORTS _ %rparen _ %semicolon _ (MODULE_ITEM:* {%function(d) {return {Type: "module_declartion", ItemList: d[0]};} %}) %endmodule _ 
        {%function(d) { return {Type: "module_old", ModuleName: d[3], PortList: d[7], ModuleItems: d[13], EndLocation: d[14].offset}; } %}

    | _ %module _ NAME_OF_MODULE _ %lparen _ (LIST_OF_PORT_DECLARATIONS _ {%function(d){return d[0];}%}):? %rparen _ %semicolon _ (NON_PORT_MODULE_ITEM:* {%function(d) {return {Type: "module_declartion", ItemList: d[0]};} %}) %endmodule _ 
        {%function(d) {return {Type: "module_new", ModuleName: d[3], IOItems: d[7], ModuleItems: d[12], EndLocation: d[13].offset};} %}

# MODULE_KEYWORD
# token ommitted, macromodule keyword not implemented, only module keyword used for MODULE_DECLARATION

#### 1.3 Module parameters and ports ####
# TODO: add support for parameters, check this for code generation 
# MODULE_PARAMETER_PORT_LIST
#     -> %hash %lparen PARAMETER_DECLARATION (%comma PARAMETER_DECLARATION {%(d) => {return d[1];}%}):* %rparen  {%function(d) {return {Type: "parameter_port_list", ParameterList: [d[2]].concat(d[3])};} %}
#     | %hash %lparen %rparem {%function(d) {return {Type: "parameter_port_list", ParameterList: null};} %}

# port list token for old style module declaration
LIST_OF_PORTS
    -> PORT _ %comma _ LIST_OF_PORTS {%function(d, l, reject) {return {Type: "list_of_ports", Head: d[0], Tail: d[4], Location: d[0].Location};} %}
    | PORT {% function(d,l,reject) {return {Type: "list_of_ports", Head: d[0], Tail: null, Location: d[0].Location};}  %}

# port list token for new style module declaration
LIST_OF_PORT_DECLARATIONS 
    -> PORT_DECLARATION _ %comma _ LIST_OF_PORT_DECLARATIONS {%function(d) {return {Type: "list_of_port_declarations", Head: d[0], Tail: d[4]};} %}
    | PORT_DECLARATION {%function(d) {return {Type: "list_of_port_declarations", Head: d[0], Tail: null};} %}

#  port token for old style module declaration, simplified to just IDENTIFIER as "multiple" declarations not supported
PORT -> IDENTIFIER {%function(d) {return {Type: "port", Port: d[0], Location: d[0].Location};} %}

# PORT_EXPRESSION
# token ommitted, not implemented

# PORT_REFERENCE
# token ommitted, not implemented

# port token for new style module declaration, inout not implemented
PORT_DECLARATION
    -> INPUT_DECLARATION  {%function(d,l, reject) {return {Type: "module_item", ItemType: "input_declaration", IODecl: d[0], ParamDecl: null, Statement: null, Location: d[0].Location};} %}
    | OUTPUT_DECLARATION  {%function(d,l, reject) {return {Type: "module_item", ItemType: "output_declaration", IODecl: d[0], ParamDecl: null, Statement: null, Location: d[0].Location};} %}

#### 1.4 Module items ####

# token for module of old style declaration, including port declaration
MODULE_ITEM
    -> PORT_DECLARATION %semicolon {%function(d,l, reject) {return d[0];} %}
    | NON_PORT_MODULE_ITEM {% id %}

# subset of non port module items, rules of unsynthesizable and unimplemented tokens are omitted
MODULE_OR_GENERATE_ITEM
    -> MODULE_OR_GENERATE_IETM_DECLARATION {% id %}
    # LOCAL_PARAMETER_DECLARATION # TODO: add support for local parameter declaration
    | CONTINUOUS_ASSIGN _ {%function(d,l, reject) {return {Type: "module_item", ItemType: "statement", IODecl: null, Decl: null, Statement: d[0], AlwaysConstruct: null, Location: d[0].Location};} %}
    | ALWAYS_CONSTRUCT {%function(d,l, reject) {return {Type: "module_item", ItemType: "always_construct", IODecl: null, Decl: null, Statement: null, AlwaysConstruct: d[0], Location: d[0].Location};} %}
    | MODULE_INSTANTIATION _ {%function(d,l, reject) { return {Type: "module_item", ItemType: "module_instantiation", IODecl: null, Decl: null, Statement: null, AlwaysConstruct: null, ModuleInstantiation: d[0], Location: d[0].Module.Location};} %}
    # LOOP_GENERATE_CONSTRUCT # TODO: add support for loop generate construct
    # CONDITIONAL_GENERATE_CONSTRUCT # TODO: add support for conditional generate construct
    
# subset of non port module items, declarations of nets and regs, logic declaration is part of SystemVerilog that is added
# data types of int, time, etc are not implemented 
MODULE_OR_GENERATE_IETM_DECLARATION
    -> LOGIC_DECLARATION _ {%function(d,l, reject) {return {Type: "module_item", ItemType: "logic_declaration", IODecl: null, Decl: d[0], Statement: null, AlwaysConstruct: null,Location: d[0].Location};} %}
    # REG_DECLARATION # TODO: add support for reg declaration
    # NET_DECLARATION # TODO: add support for net declaration
    # GENVAR_DECLARATION # TODO: add support for genvar declaration
    
# token for module of new style declaration, specify block and associated specparam not implemented
NON_PORT_MODULE_ITEM
    -> MODULE_OR_GENERATE_ITEM {% id %}
    # | GENERATE_REGION # TODO: add support for generate region
    # | PARAMETER_DECLARATION # TODO: add support for parameter declaration

# PARAMETER_OVERRIDE
# not implemented, old style of overriding parameters and warned by most synthesis tools

#### 1.5 Configuration source text ####
# Out of scope for project, not implemented

##################### 2. Declarations ####################
#### 2.1 Declaration types ####
### 2.1.1 Module parameter declaration ###
# TODO: add support for module parameter declaration

### 2.1.2 Port declarations ###

### TODO: add support for other net types and logic types
INPUT_DECLARATION -> input _ (%bit _ ) (RANGE _ {%(d) => {return d[0]}%}):? LIST_OF_PORT_IDENTIFIERS  {%function(d) {
    return {Type: "declaration", DeclarationType: "input", Range: d[3], Variables: d[4], Location: d[0].Location};} %}

### TODO: add support for other net types and reg, simplify grammar such output reg also uses variable identifier
OUTPUT_DECLARATION -> output _ (%bit _ ) (RANGE _ {%(d) => {return d[0]}%}):? LIST_OF_PORT_IDENTIFIERS {%function(d) {
    return {Type: "declaration", DeclarationType: "output", Range: d[3], Variables: d[4], Location: d[0].Location};} %}

# INOUT_DECLARATION 
# not implemented, inout not supported

### 2.1.3 Type declarations ###

# bit and logic from SystemVerilog are used, they are handled both as 2 state variable due to issie limitations
LOGIC_DECLARATION 
    -> %bit _  (RANGE _ {%(d,l,r) => {return d[0]}%}):? LIST_OF_VARIABLE_IDENTIFIERS _ %semicolon {% (d,l,r) => {
        return {Type: "declaration", DeclarationType: "internal", Range: d[2], Variables: d[3], Location: d[0].offset};} %}

# REG_DECLARATION
# TODO: add support for reg declaration

# NET_DECLARATION
# TODO: add support for net declaration

#### 2.2 Declaration data types ####
### 2.2.1 Net and variable types ###
# TODO: add support with dimension which handles arrays
VARIABLE_TYPE
    -> IDENTIFIER {% id %}

### 2.2.2 Strenths ###
# not implemented, strength not supported

### 2.2.3 Delays ###
# not implemented, delay not supported
    

#### 2.3 Declaration lists ####
# LIST_OF_DEFPARAM_ASSIGNMENTS 
# used for parameter overrides, not implemented

# LIST_OF_EVENT_IDENTIFIERS
# not implemented, complex event control not supported

# LIST_OF_NET_DECL_ASSIGNMENTS 
# declaration of nets with initilization not synthesizable, not implemented

# LIST_OF_NET_IDENTIFIERS # TODO: add support for net declaration

# LIST_OF_PARAM_ASSIGNMENTS # TODO: add support for parameter assignment

LIST_OF_PORT_IDENTIFIERS
    -> PORT_IDENTIFIER _ %comma _ LIST_OF_PORT_IDENTIFIERS {%function(d) {return {Type: "variable_list", Head: d[0], Tail: d[4]};} %}
    | PORT_IDENTIFIER {% function(d) {return {Type: "variable_list", Head: d[0], Tail: null};}  %}

# LIST_OF_REAL_IDENTIFIERS
# not implemented, real and realtime not supported

# LIST_OF_SPECPARAM_IDENTIFIERS
# not implemented, specparam not supported

LIST_OF_VARIABLE_IDENTIFIERS
    -> VARIABLE_TYPE _ %comma _ LIST_OF_VARIABLE_IDENTIFIERS {%function(d) {return [d[0]].concat(d[4]) ;} %}
    | VARIABLE_TYPE {% function(d) {return [d[0]];}  %}

# LIST_OF_VARAIBLE_PORT_IDENTIFIERS
# token ommitted from simplified output reg grammar, not implemented

#### 2.4 Declaration assignments ####

# PARAM_ASSIGNMENT
# TODO: add support for parameter assignment

#### 2.5 Declaration ranges ####
# DIMENSION # TODO: add support for dimension which handles arrays

# TODO; fix this with constant expression and primary
RANGE -> %lbracket _ UNSIGNED_NUMBER _ %colon _ UNSIGNED_NUMBER _ %rbracket {%function(d,l,reject) {return {Type: "range", Start: d[2], End: d[6], Location: d[0].offset};} %}

# 2.6 Function declarations
# not implemented, function declaration not supported

# 2.7 Task declarations
# not implemented, task declaration not supported

# 2.8 Block item declarations
# not implemented, block item declaration not supported
# declarations in procedural blocks can be synthesizeable but not always, 
# often used as loop statement index which tends to be more purposed for simulation



PORT_IDENTIFIER -> IDENTIFIER {%function(d) {return {Type: "variable", Name: d[0], Location: d[0].Location};} %}




NAME_OF_MODULE -> IDENTIFIER {% id %}









#### reg declaration #####

######################################     BEHAVIORAL STATEMENTS    #############################################

### PROCEDURAL BLOCKS AND ASSIGNMENTS

#initial_construct -> "initial" statement_or_null #maybe dont need it
ALWAYS_CONSTRUCT
    -> %always_comb _ STATEMENT {%function(d) {
        return {Type: "always_construct", AlwaysType: d[0].value, Statement: d[2], ClkLoc: 0, Location: d[0].offset};} %}
    | %always_ff _ %at _ %lparen _ %posedge _ "clk" _ %rparen _ STATEMENT {%function(d) {
        return {Type: "always_construct", AlwaysType: d[0].value, Statement: d[12], ClkLoc: d[8].offset, Location: d[0].offset};} %}

#ALWAYS_KEYWORD -> "always" {% id %} | "always_comb" {% id %} | "always_latch" {% id %} | "always_ff" {% id %} #remove latch and maybe basic
#final_construct -> "final" function_statement # maybe dont need it

BLOCKING_ASSIGNMENT ->
    # VARIABLE_LVALUE "=" EXPRESSION {%function(d) {return {Type: "blocking_assignment", LHS: d[0]}, RHS: d[2];} %}# dont need delay DELAY_OR_EVENT_CONTROL
    #| NONRANGE_VARIABLE_LVALUE "=" DYNAMIC_ARRAY_NEW #probs dont need it
    # | [ implicit_class_handle . | class_scope | package_scope ] hierarchical_variable_identifier #figure out what this is
    #select = class_new
    OPERATOR_ASSIGNMENT {%function(d) { return {Assignment: {Type: "blocking_assignment", Operator: d[0].Operator, Assignment: d[0].Assignment}, Location:d[0].Location};} %}

OPERATOR_ASSIGNMENT -> VARIABLE_LVALUE _ ASSIGNMENT_OPERATOR _ EXPRESSION
    {%function(d) { return {Type: "operator_assignment", Operator: d[2].Operator, Assignment: {Type: "assign", LHS: d[0], RHS: d[4]}, Location: d[2].Location};} %}

ASSIGNMENT_OPERATOR ->
    %op_assign {% (d)=>{return {Operator: d[0].value, Location: d[0].offset}} %}

NONBLOCKING_ASSIGNMENT ->
    VARIABLE_LVALUE _ %lte _ EXPRESSION #don't need delay or event control [ delay_or_event_control ]
    {%function(d) {return {Assignment: {Type: "nonblocking_assignment", Assignment: {Type: "assign", LHS: d[0], RHS: d[4]}}, Location: d[2].offset};} %}

#PROCEDURAL_CONTINUOUS_ASSIGNMENT ->
    #"assign" VARIABLE_ASSIGNMENT
    #| deassign variable_lvalue
    #| force variable_assignment
    #| force net_assignment
    #| release variable_lvalue
    #| release net_lvalue

#VARIABLE_ASSIGNMENT -> VARIABLE_LVALUE "=" EXPRESSION

VARIABLE_LVALUE -> 
    L_VALUE {% id %}
    | VARIABLE_BITSELECT_L_VALUE {% id %}

#need multiple statements not just one
SEQ_BLOCK
    -> %begin _ SEQ_BLOCK_STMTS %end _ {% function(d) {return{Type: "seq_block", Statements: d[2], Location: d[0].offset}; } %}# not sure if this is correct

SEQ_BLOCK_STMTS -> STATEMENT:+ {% function(d) {return d[0]}%}

CONDITIONAL_STATEMENT ->
    # IF ELSE_IF:* ELSE:? {%function(d) {if_statements=[d[0]].concat(d[1]); return {Type: "cond_stmt", IfStatements: if_statements, ElseStatement: d[2]}}%}
    IF ELSE:? {% function(d) {return {Type: "cond_stmt", IfStatement: d[0], ElseStatement: d[1], Location: d[0].Location};} %}

STATEMENT -> COMPLETE_STATEMENT {%id%}
        | INCOMPLETE_CONDITIONAL_STATEMENT {%id%}

COMPLETE_STATEMENT 
    -> COMPLETE_CONDITIONAL_STATEMENT  {%id%}
    | NONBLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject) {
            //let len = d[2].offset-d[0].Assignment.LHS.Primary.Location+1;
            //const name = 'a'.repeat(len);
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "<=";
            return {Type: "statement", StatementType: "nonblocking_assignment", NonBlockingAssign: assignment, BlockingAssign: null, SeqBlock: null, Conditional: null, CaseStatement: null, Location: d[0].Location};
        } %}
    | BLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject){
            //let len = d[2].offset-d[0].Assignment.LHS.Primary.Location+1;
            //const name = 'a'.repeat(len);
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "=";
            return {Type: "statement", StatementType: "blocking_assignment", NonBlockingAssign: null, BlockingAssign: assignment, SeqBlock: null, Conditional: null,  CaseStatement: null, Location: d[0].Location};
        } %}
    | SEQ_BLOCK {%function(d,l,reject) {return {Type: "statement", StatementType: "seq_block", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: d[0], Conditional: null,  CaseStatement: null, Location: d[0].Location};} %} #change to statements?
    | CASE_STATEMENT {%function(d,l,reject) {return {Type: "statement", StatementType: "case_stmt", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: null,  CaseStatement: d[0], Location: d[0].Location};}%}

COMPLETE_CONDITIONAL_STATEMENT 
    -> %t_if _ %lparen _ EXPRESSION _ %rparen _ COMPLETE_STATEMENT  %t_else _ COMPLETE_STATEMENT {% function(d) {
        let ifStmt = {Type: "ifstmt", Condition: d[4], Statement: d[8], Location: d[0].offset};
        let conditional = {Type: "cond_stmt", IfStatement: ifStmt, ElseStatement: d[11], Location: d[0].offset};
        return {Type: "statement", StatementType: "conditional", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: conditional,  CaseStatement: null, Location: d[0].offset}
        } %}

INCOMPLETE_CONDITIONAL_STATEMENT 
    -> %t_if _ %lparen _ EXPRESSION _ %rparen _ STATEMENT {% function(d) {
        let ifStmt = {Type: "ifstmt", Condition: d[4], Statement: d[8], Location: d[0].offset};
        let conditional = {Type: "cond_stmt", IfStatement: ifStmt, ElseStatement: null, Location: d[0].offset};
        return {Type: "statement", StatementType: "conditional", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: conditional,  CaseStatement: null, Location: d[0].offset}
        } %}
    | %t_if _ %lparen _ EXPRESSION _ %rparen _ COMPLETE_STATEMENT  %t_else _ INCOMPLETE_CONDITIONAL_STATEMENT {% function(d) {
        let ifStmt = {Type: "ifstmt", Condition: d[4], Statement: d[8], Location: d[0].offset};
        let conditional = {Type: "cond_stmt", IfStatement: ifStmt, ElseStatement: d[11], Location: d[0].offset};
        return {Type: "statement", StatementType: "conditional", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: conditional,  CaseStatement: null, Location: d[0].offset}
    } %}

# this might be ambiguous grammar? I want to have it this way because code gen should be easier maybe
IF -> %t_if _ %lparen _ EXPRESSION _ %rparen _ STATEMENT {% function(d) {return {Type: "ifstmt", Condition: d[4], Statement: d[8], Location: d[0].offset}; } %}
ELSE_IF -> %t_else _ %t_if _ %lparen _ EXPRESSION _ %rparen _ STATEMENT {% function(d) {return {Condition: d[6], Statement: d[10]}; } %}
ELSE -> %t_else _ STATEMENT {% function(d) {return d[2]; } %}

STATEMENT2
    -> NONBLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject) {
            //let len = d[2].offset-d[0].Assignment.LHS.Primary.Location+1;
            //const name = 'a'.repeat(len);
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "<=";
            return {Type: "statement", StatementType: "nonblocking_assignment", NonBlockingAssign: assignment, BlockingAssign: null, SeqBlock: null, Conditional: null, CaseStatement: null, Location: d[0].Location};
        } %}
    | BLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject){
            //let len = d[2].offset-d[0].Assignment.LHS.Primary.Location+1;
            //const name = 'a'.repeat(len);
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "=";
            return {Type: "statement", StatementType: "blocking_assignment", NonBlockingAssign: null, BlockingAssign: assignment, SeqBlock: null, Conditional: null,  CaseStatement: null, Location: d[0].Location};
        } %}
    | SEQ_BLOCK {%function(d,l,reject) {return {Type: "statement", StatementType: "seq_block", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: d[0], Conditional: null,  CaseStatement: null, Location: d[0].Location};} %} #change to statements?
    | CONDITIONAL_STATEMENT {%function(d,l,reject) {return {Type: "statement", StatementType: "conditional", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: d[0],  CaseStatement: null, Location: d[0].Location};}%}
    | CASE_STATEMENT {%function(d,l,reject) {return {Type: "statement", StatementType: "case_stmt", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: null,  CaseStatement: d[0], Location: d[0].Location};}%}

################# CASE STATEMENTS ###################
CASE_STATEMENT # probs only care about first one
    -> %t_case _ %lparen _ EXPRESSION _ %rparen _ (CASE_ITEM {% id %}):+  DEFAULT:? %t_endcase _ {%function(d) { 
        return {Type: "case_stmt", Expression: d[4], CaseItems: d[8], Default: d[9], Location: d[0].offset};}%}
    #| CASE_KEYWORD (case_expression ) "matches" case_pattern_item { case_pattern_item } endcase
    #|  "case" ( case_expression ) "inside"
    #   case_inside_item { case_inside_item } endcase


# for clarity default should be last
DEFAULT
    -> %t_default _ %colon _ STATEMENT {% function(d){return d[4];}%}
CASE_ITEM
    -> NUMBER  _ (%comma _ NUMBER _ {%function(d){return d[2];}%}):*  %colon _ STATEMENT
        {% function(d) {expr = [d[0]].concat(d[2]); return {Type: "case_item", Expressions: expr, Statement: d[5]};}%}
    #| default [ : ] statement_or_null

# case_pattern_item ::=
#     pattern [ &&& expression ] : statement_or_null
#     | default [ : ] statement_or_null
# case_inside_item ::=
#     open_range_list : statement_or_null
#     | default [ : ] statement_or_null



# EDGE_IDENTIFIER -> "posedge" | "negedge" | "edge"

# EVENT_EXPRESSION
#     -> EDGE_IDENTIFIER:? EXPRESSION ("iff" _ EXPRESSION):?
#     #| sequence_instance [ iff expression ] # check what this is!
#     | EVENT_EXPRESSION _ "or" _ EVENT_EXPRESSION
#     | EVENT_EXPRESSION _ "," _ EVENT_EXPRESSION
#     | "(" _ EVENT_EXPRESSION _ ")"

# PROCEDURAL_TIMING_CONTROL
#     -> "@" IDENTIFIER  #hierarchical_event_identifier
#     | "@" _ "(" EVENT_EXPRESSION ")"
#     | "@" _ "*"
#     | "@" _ "(" _ "*" _ ")"
#     #| "@" ps_or_hierarchical_sequence_identifier


CONTINUOUS_ASSIGN
    -> assign _ ASSIGNMENT _ %semicolon {%function(d) {return {Type: "statement", StatementType: "assign", Assignment: d[2], Location: d[0].Location};} %}
    | logic _ WIRE_ASSIGNMENT _ %semicolon {%function(d) {return {Type: "statement", StatementType: "wire", Assignment: d[2], Location: d[0].Location};} %}

ASSIGNMENT -> L_VALUE _ %op_assign _ EXPRESSION {%function(d) {return {Type: "assign", LHS: d[0], RHS: d[4], Location:d[0].Primary.Location};} %}

WIRE_ASSIGNMENT -> WIRE_L_VALUE _ %op_assign _ EXPRESSION {%function(d) {return {Type: "bit", LHS: d[0], RHS: d[4], Location:d[0].Primary.Location };} %} 

###########################################      MODULE_DECLARATION INSTANTIATION STATEMENTS    #############################
MODULE_INSTANTIATION -> IDENTIFIER _ IDENTIFIER _ %lparen _ LIST_OF_PORT_CONNECTIONS _ %rparen _ %semicolon {%(d) => {return {Type: "module_instantiation", Module: d[0], Identifier: d[2], Connections: d[6]}}%}

LIST_OF_PORT_CONNECTIONS ->
        NAMED_PORT_CONNECTION  (_ %comma _ NAMED_PORT_CONNECTION {%(d)=> {return d[3];}%}):* _ {%(d) => {return [d[0]].concat(d[1]);}%}

NAMED_PORT_CONNECTION ->
        %dot _ IDENTIFIER _ %lparen _ MODULE_INSTANTIATION_PRIMARY _ %rparen {% (d) => {return {Type: "named_port_connection", PortId: d[2], Primary: d[6]}}%}

MODULE_INSTANTIATION_PRIMARY
    -> IDENTIFIER {%function(d) {return {Type: "primary", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bit", BitsStart: d[3], BitsEnd: d[3], Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %colon UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bits", BitsStart: d[3], BitsEnd: d[5], Primary: d[0]};} %}
###########################################      EXPRESSIONS      ###############################################

WIRE_L_VALUE
    -> IDENTIFIER {%function(d) {return {Type: "l_value", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0]};} %}
    | %lbracket UNSIGNED_NUMBER %colon UNSIGNED_NUMBER %rbracket _ IDENTIFIER {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: d[1], BitsEnd: d[3], Primary: d[6]};} %}

L_VALUE
    -> IDENTIFIER {%function(d) {return {Type: "l_value", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bit", BitsStart: d[3], BitsEnd: d[3], Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %colon UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: d[3], BitsEnd: d[5], Primary: d[0]};} %}

VARIABLE_BITSELECT_L_VALUE
    -> IDENTIFIER _ %lbracket EXPRESSION %rbracket {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: null, BitsEnd: null, Primary: d[0], VariableBitSelect: d[3], Width: 1};} %}
    #| IDENTIFIER _ %lbracket EXPRESSION _ %minus _ %colon UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: null, BitsEnd: null, Primary: d[0], VariableBitSelect: d[3], Width: parseInt(d[8].value)};} %} 


EXPRESSION -> CONDITIONAL {% id %}

CONDITIONAL
    -> LOGICAL_OR _ %question _ CONDITIONAL_RESULT {%function(d) {return {Type: "conditional_cond", Operator:d[2].value, Head: d[0], Tail: d[4]};} %}
    | LOGICAL_OR {% id %}

CONDITIONAL_RESULT
    -> LOGICAL_OR _ %colon _ LOGICAL_OR {%function(d) {return {Type: "conditional_result", Operator:d[2].value, Head: d[0], Tail: d[4]};} %}

LOGICAL_OR
    -> LOGICAL_OR _ %lor _ LOGICAL_AND {%function(d) {return {Type: "logical_OR", Operator:d[2].value, Head: d[0], Tail: d[4]};} %}
    | LOGICAL_AND {% id %}

LOGICAL_AND
    -> LOGICAL_AND _ %land _ BITWISE_OR {%function(d) {return {Type: "logical_AND", Operator:d[2].value, Head: d[0], Tail: d[4]};} %}  
    | BITWISE_OR {% id %}

BITWISE_OR 
    -> BITWISE_OR _ %or _ BITWISE_XOR {%function(d) {return {Type: "bitwise_OR", Operator:d[2].value, Head: d[0], Tail: d[4]};} %}
    | BITWISE_XOR {% id %}

BITWISE_XOR  
    -> BITWISE_XOR _ XOR_XNOR_OPERATOR _ BITWISE_AND {%function(d) {return {Type: "bitwise_XOR", Operator:d[2], Head: d[0], Tail: d[4]};} %}
    | BITWISE_AND {% id %}

BITWISE_AND 
    -> BITWISE_AND _ %and _ LOGICAL_SHIFT {%function(d) {return {Type: "bitwise_AND", Operator:d[2].value, Head: d[0], Tail: d[4]};} %}
    | EQUALITY {% id %}

# here put case equality, logical equality, comparison
EQUALITY
    -> EQUALITY _ EQUALITY_OPERATOR _ COMPARISON {%function(d) {return {Type: "equality", Operator:d[2], Head: d[0], Tail: d[4]};} %}
    | COMPARISON {% id %}

COMPARISON
    -> COMPARISON _ RELATIONAL_OPERATOR _ LOGICAL_SHIFT {%function(d) {return {Type: "comparison", Operator:d[2], Head: d[0], Tail: d[4]};} %}
    | LOGICAL_SHIFT {% id %}

LOGICAL_SHIFT
    -> LOGICAL_SHIFT _ SHIFT_OPERATOR _ UNSIGNED_REDUCTED {%function(d) {return {Type: "SHIFT", Operator:d[2], Head: d[0], Tail: d[4]};} %}
    | LOGICAL_SHIFT _ SHIFT_OPERATOR _ ADDITIVE {%function(d) {return {Type: "SHIFT", Operator:d[2], Head: d[0], Tail: d[4]};} %}
    | ADDITIVE {% id %}

ADDITIVE
    -> ADDITIVE _ ADDITIVE_OPERATOR _ MULTIPLICATIVE {%function(d) {return {Type: "additive", Operator:d[2], Head: d[0], Tail: d[4]};} %}
    | MULTIPLICATIVE {% id %}

MULTIPLICATIVE
    -> MULTIPLICATIVE _ MULTIPLICATION_OPERATOR _ REDUCTION_OR_NEGATION {%function(d) {return {Type: "multiplicative", Operator:d[2], Head: d[0], Tail: d[4]};} %}
    | REDUCTION_OR_NEGATION {% id %}

REDUCTION_OR_NEGATION
    -> %lparen _ UNARY_OPERATOR _ UNARY _ %rparen {%function(d) {return {Type: "reduction", Operator:d[2], Unary: d[4]};} %}
    | %not _ UNARY {%function(d) {return {Type: "negation", Operator: "~", Unary: d[2]};} %}
    | UNARY {%function(d) {return {Type: "unary", Unary: d[0]};} %}

UNARY 
    -> PRIMARY {%function(d) {return {Type: "primary", Primary: d[0], Number: null, Expression: d[0].Expression};} %}
    | NUMBER {%function(d) {return {Type: "number", Primary: null, Number: d[0], Expression: null};} %}
    | %lparen _ BITWISE_OR _ %rparen {%function(d) {return {Type: "parenthesis", Primary: null, Number: null, Expression: d[2]};} %}
    | %lbrace _ LIST_OF_UNARIES _ %rbrace {%function(d) {return {Type: "concat", Primary: null, Number: null, Expression: d[2]};} %}


LIST_OF_UNARIES
    -> EXPRESSION _ %comma _ LIST_OF_UNARIES {%function(d) {return {Type: "unary_list", Head : d[0], Tail: d[4]};} %}
    | EXPRESSION {% function(d) {return {Type: "unary_list", Head: d[0], Tail: null};}  %}


#### Used for unsigned numbers (only in logical/arithmetic shifts)
UNSIGNED_REDUCTED 
    -> UNSIGNED_UNARY {%function(d) {return {Type: "unary_unsigned", Unary: d[0]};} %}

UNSIGNED_UNARY
    -> U_NUMBER {%function(d) {return {Type: "number", Primary: null, Number: d[0], Expression: null};} %}

U_NUMBER
    -> %unsigned_number {%function(d,l,reject) {return {Type: "number", NumberType: "decimal", Bits: null, Base: null, UnsignedNumber: d[0].value, AllNumber: null, Location: d[0].offset};} %}

##############
EQUALITY_OPERATOR -> %eq {%(d)=>{return d[0].value}%} | %neq {%(d)=>{return d[0].value}%} 

RELATIONAL_OPERATOR -> %lt {%(d)=>{return d[0].value}%} | %lte {%(d)=>{return d[0].value}%} | %gt {%(d)=>{return d[0].value}%} | %gte {%(d)=>{return d[0].value}%} 

ADDITIVE_OPERATOR -> %plus {%(d)=>{return d[0].value}%} | %minus {%(d)=>{return d[0].value}%} 

XOR_XNOR_OPERATOR -> %xor_xnor {%(d)=>{return d[0].value}%} 

SHIFT_OPERATOR -> %sll {%(d)=>{return d[0].value}%} | %srl {%(d)=>{return d[0].value}%} | %sra {%(d)=>{return d[0].value}%} 

UNARY_OPERATOR -> %lnot {%(d)=>{return d[0].value}%}  | %and {%(d)=>{return d[0].value}%}  | %nand {%(d)=>{return d[0].value}%} | %or {%(d)=>{return d[0].value}%} | %nor {%(d)=>{return d[0].value}%} #{%function(d) {return d[0].join('');} %}

MULTIPLICATION_OPERATOR -> %mult {%(d)=>{return d[0].value}%} 


PRIMARY
    -> IDENTIFIER {%function(d) {return {Type: "primary", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket _ UNSIGNED_NUMBER _ %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bit", BitsStart: d[4], BitsEnd: d[4], Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket _ UNSIGNED_NUMBER _ %colon _ UNSIGNED_NUMBER _ %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bits", BitsStart: d[4], BitsEnd: d[8], Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket _ EXPRESSION _ %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bit2", BitsStart: null, BitsEnd: null, Primary: d[0], Expression: d[4], Width:1};} %}
    #| IDENTIFIER _ %lbracket _ EXPRESSION _ %minus _ %colon _ UNSIGNED_NUMBER _ %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bit2", BitsStart: null, BitsEnd: null, Primary: d[0], Expression: d[4], Width:parseInt(d[10].value)};} %}


NUMBER
    -> %unsigned_number ALL_NUMERIC {%function(d,l,reject) {
        let num = d[1].slice(2);
        return {Type: "number", NumberType: "all", Bits: d[0].value, Base: "'h", UnsignedNumber: null, AllNumber: num, Location: d[0].offset};
        } %}
    | %unsigned_number BINARY_NUMBER {%function(d,l,reject) {
        let num = d[1].slice(2);
        return {Type: "number", NumberType: "all", Bits: d[0].value, Base: "'b", UnsignedNumber: null, AllNumber: num, Location: d[0].offset};
        } %}
    | %unsigned_number %decimalBase UNSIGNED_NUMBER {%function(d,l,reject) {return {Type: "number", NumberType: "all", Bits: d[0].value, Base: "'d", UnsignedNumber: null, AllNumber: d[2], Location: d[0].offset};} %}
    

UNSIGNED_NUMBER -> %unsigned_number {%(d)=>{return d[0].value}%}

ALL_NUMERIC -> %all_numeric {%(d)=>{return d[0].value}%}

BINARY_NUMBER -> %binary {%(d)=>{return d[0].value}%} 


#HEX_DIGIT -> %binary {%d => {return d[0].value}%} | %unsigned_number {%d => { return d[0].value}%}  | %all_numeric {%d => {return d.value}%}
#DECIMAL_DIGIT -> %unsigned_number {%d => { return d[0].value}%} | %binary {%d => {return d[0].value}%}
#BINARY_DIGIT -> %binary {%d => {return d[0].value}%}

#BASE -> "'b" | "'h" {% id %}

CONCAT 
    -> EXPRESSION _ %comma _ CONCAT {%function(d) {return {Type: "concatenation_list", Head: d[0], Tail: d[4]};} %}
    | EXPRESSION {% function(d) {return {Type: "concatenation_list", Head: d[0], Tail: null};}  %}


##############################################    GENERAL    #################################################

input -> %input {% d=>{return {Location: d[0].offset}} %}
output -> %output {% d=>{return {Location: d[0].offset}} %}
parameter -> %parameter {% id %}
assign -> %assign {% d=>{return {Location: d[0].offset}} %}
wire -> %wire {% d=>{return {Location: d[0].offset}} %}
logic -> %bit {% d=>{return {Location: d[0].offset}} %}
endmodule -> %endmodule {% d=>{return {Location: d[0].offset}} %}
 
EVERYTHING -> %EVERYTHING

IDENTIFIER -> %IDENTIFIER {%
    function(d,l, reject) {
        //const keywords = ["alias","and","assert","assign","assume","automatic","before","begin","bind","bins","binsof","bit","break","buf","bufif0","bufif1","byte","case","casex","casez","cell","chandle","class","clocking","cmos","config","const","constraint","context","continue","cover","covergroup","coverpoint","cross","deassign","default","defparam","design","disable","dist","do","edge","else","end","endcase","endclass","endclocking","endconfig","endfunction","endgenerate","endgroup","endinterface","endmodule","endpackage","endprimitive","endprogram","endproperty","endsequence","endspecify","endtable","endtask","enum","event","expect","export","extends","extern","final","first_match","for","force","foreach","forever","fork","forkjoin","function","generate","genvar","highz0","highz1","if","iff","ifnone","ignore_bins","illegal_bins","import","incdir","include","initial","inout","input","inside","instance","int","integer","interface","intersect","join","join_any","join_none","large","liblist","library","local","localparam","logic","longint","macromodule","matches","medium","modport","module","nand","negedge","new","nmos","nor","noshowcancelled","not","notif0","notif1","null","or","output","package","packed","parameter","pmos","posedge","primitive","priority","program","property","protected","pull0","pull1","pulldown","pullup","pulsestyle_ondetect","pulsestyle_onevent","pure","rand","randc","randcase","randsequence","rcmos","real","realtime","ref","reg","release","repeat","return","rnmos","rpmos","rtran","rtranif0","rtranif1","scalared","sequence","shortint","shortreal","showcancelled","signed","small","solve","specify","specparam","static","string","strong0","strong1","struct","super","supply0","supply1","table","tagged","task","this","throughout","time","timeprecision","timeunit","tran","tranif0","tranif1","tri","tri0","tri1","triand","trior","trireg","type","typedef","union","unique","unsigned","use","uwire","var","vectored","virtual","void","wait","wait_order","wand","weak0","weak1","while","wildcard","wire","with","within","wor","xnor","xor"]
        const name = d[0].value; //+ d[1].join('');
        // if (keywords.includes(name)) {
        //     return reject;
        // } else {
        //     return  {Name: name, Location: l};
        // }
        return  {Name: name, Location: d[0].offset};
    }
%}

_ -> %ws:*
_ -> %ws:+ 

