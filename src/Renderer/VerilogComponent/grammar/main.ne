# To compile the .ne file to .js file:
#   1. Install the nearley compiler
#   2. Be in this directory containing the grammar file
#   3. Run: "npx nearleyc ./grammar/main.ne -o ./VerilogGrammar.js"

@include "./lexer.ne"
@include "./statement.ne"
@include "./expression.ne"

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
    -> %module MODULE_IDENTIFIER MODULE_PARAMETER_PORT_LIST:? %lparen LIST_OF_PORTS %rparen %semicolon (MODULE_ITEM:* {%function(d) {return {Type: "module_declartion", ItemList: d[0]};} %}) %endmodule 
        {%function(d) { return {Type: "module_old", 
                                ModuleName: d[1], 
                                ParameterList: d[2], // actually not part of final AST, processed in later step into module items
                                PortList: d[4], 
                                ModuleItems: d[7], 
                                EndLocation: d[8].offset}; } %}

    | %module MODULE_IDENTIFIER MODULE_PARAMETER_PORT_LIST:? %lparen (LIST_OF_PORT_DECLARATIONS {%function(d){return d[0];}%}):? %rparen %semicolon (NON_PORT_MODULE_ITEM:* {%function(d) {return {Type: "module_declartion", ItemList: d[0]};} %}) %endmodule 
        {%function(d) {return {Type: "module_new", 
                                ModuleName: d[1], 
                                ParameterList: d[2], // actually not part of final AST, processed in later step into module items
                                PortDeclarations: d[4], // actually not part of final AST, processed in later step into module items
                                ModuleItems: d[7], 
                                EndLocation: d[8].offset};} %}

# MODULE_KEYWORD
# token ommitted, macromodule keyword not implemented, only module keyword used for MODULE_DECLARATION

#### 1.3 Module parameters and ports ####
# TODO: add support for parameters, check this for code generation 
MODULE_PARAMETER_PORT_LIST
    -> %hash %lparen PARAMETER_DECLARATION (%comma PARAMETER_DECLARATION {%(d) => {return d[1];}%}):* %rparen  
        {%function(d) {return [d[2]].concat(d[3])} %}

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
    | LOOP_GENERATE_CONSTRUCT {% id %}
    | CONDITIONAL_GENERATE_CONSTRUCT {% id %}
    
# subset of non port module items, declarations of nets and regs, logic declaration is part of SystemVerilog that is added
# data types of int, time, etc are not implemented 
MODULE_OR_GENERATE_IETM_DECLARATION
    -> LOGIC_DECLARATION _ {%function(d,l, reject) {return {Type: "module_item", ItemType: "logic_declaration", IODecl: null, Decl: d[0], Statement: null, AlwaysConstruct: null,Location: d[0].Location};} %}
    # REG_DECLARATION # TODO: add support for reg declaration
    # NET_DECLARATION # TODO: add support for net declaration
    | GENVAR_DECLARATION {% id %}# TODO: add support for genvar declaration
    
# token for module of new style declaration, specify block and associated specparam not implemented
NON_PORT_MODULE_ITEM
    -> MODULE_OR_GENERATE_ITEM {% id %}
    | GENERATE_REGION {% id %} # TODO: add support for generate region
    | PARAMETER_DECLARATION %semicolon #{% (d) => {return d[0];} %}
    {% (d) => {return {Type:"module_item", ItemType: "parameter_declaration", ParamDecl: d[0], Location: d[0].Location};}%}

# PARAMETER_OVERRIDE
# not implemented, usually used only in simulation to update parameters without reinstantiating module

#### 1.5 Configuration source text ####
# Out of scope for project, not implemented

##################### 2. Declarations ####################
#### 2.1 Declaration types ####
### 2.1.1 Module parameter declaration ###
# TODO: add support for module parameter declaration
PARAMETER_DECLARATION # range and signed not supported for parameter
    -> %parameter LIST_OF_PARAM_ASSIGNMENTS
        # {% (d) => {return 123} %}
        {% function(d) {return {Type: "parameter_declaration", ParameterAssignmentList: d[1], Location: d[0].offset};} %}

### 2.1.2 Port declarations ###

### TODO: add support for other net types and logic types
INPUT_DECLARATION -> %input _ (%bit _ ) (RANGE _ {%(d) => {return d[0]}%}):? LIST_OF_PORT_IDENTIFIERS  {%function(d) {
    return {Type: "declaration", DeclarationType: "input", Range: d[3], Variables: d[4], Location: d[0].offset};} %}

### TODO: add support for other net types and reg, simplify grammar such output reg also uses variable identifier
OUTPUT_DECLARATION -> %output _ (%bit _ ) (RANGE _ {%(d) => {return d[0]}%}):? LIST_OF_PORT_IDENTIFIERS {%function(d) {
    return {Type: "declaration", DeclarationType: "output", Range: d[3], Variables: d[4], Location: d[0].offset};} %}

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
    | IDENTIFIER (%lbracket CONSTANT_EXPRESSION %colon CONSTANT_EXPRESSION %rbracket {% function(d) {return [ [d[1],d[3]] ];} %}):+ 
        {% function(d,l,reject) {
            return {$type: "IdentifierDimension", Identifier: d[0], Dimension: d[1].flat(), Location:d[0].Location};
        } %}

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

LIST_OF_PARAM_ASSIGNMENTS 
    -> PARAM_ASSIGNMENT  %comma LIST_OF_PARAM_ASSIGNMENTS {% (d) => {return [d[0]].concat(d[2])} %}
    | PARAM_ASSIGNMENT {% (d) => {return [d[0]];} %}
        
LIST_OF_PORT_IDENTIFIERS
    -> PORT_IDENTIFIER _ %comma _ LIST_OF_PORT_IDENTIFIERS {%function(d) {return {Type: "list_of_port_identifiers", Head: d[0], Tail: d[4]};} %}
    | PORT_IDENTIFIER {% function(d) {return {Type: "list_of_port_identifiers", Head: d[0], Tail: null};}  %}

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

PARAM_ASSIGNMENT # simplified to constant expression as minmaxtyp not supported
    -> IDENTIFIER %op_assign CONSTANT_EXPRESSION {% function(d) {return {Type: "param_assignment", ParameterIdentifier: d[0], ParameterRHS:d[2]};} %}


#### 2.5 Declaration ranges ####
# DIMENSION # TODO: add support for dimension which handles arrays

# TODO; fix this with constant expression and primary
RANGE -> %lbracket _ UNSIGNED_NUMBER _ %colon _ UNSIGNED_NUMBER _ %rbracket 
    {%function(d,l,reject) {
        // TODO: this is a temporary fix to handle range, fix this later when more constant expression is implemented
        let start = {Type: "constant_expression", Location: d[0].offset, ConstantExpression: {Type: "unary", Location: d[0].offset, 
            Unary:{Type: "number", Location: d[0].offset, 
                Number: {Type: "number", NumberType: "all", Bits: "32", Base: "'d", AllNumber: d[2], Location: d[0].offset}}}};
        let end = {Type: "constant_expression", Location: d[0].offset, ConstantExpression: {Type: "unary", Location: d[4].offset,
            Unary:{Type: "number", Location: d[4].offset, 
                Number: {Type: "number", NumberType: "all", Bits: "32", Base: "'d", AllNumber: d[6], Location: d[4].offset}}}};
        // return {Type: "range", Start: d[2], End: d[6], Location: d[0].offset};
        return {Type: "range", Start: start, End: end, Location: d[0].offset};
    } %}
    | %lbracket CONSTANT_EXPRESSION %colon CONSTANT_EXPRESSION %rbracket 
    {%function(d,l,reject) {
        return {Type: "range", Start: d[1], End: d[3], Location: d[0].offset};
    } %}

# 2.6 Function declarations
# not implemented, function declaration not supported

# 2.7 Task declarations
# not implemented, task declaration not supported

# 2.8 Block item declarations
# not implemented, block item declaration not supported
# declarations in procedural blocks can be synthesizeable but not always, 
# often used as loop statement index which tends to be more purposed for simulation

################### 3. Primitive instances ###################
# not implemented, primitive instances not supported