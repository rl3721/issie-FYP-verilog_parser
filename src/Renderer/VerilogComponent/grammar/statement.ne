@include "./lexer.ne"
@include "./expression.ne"
@lexer lexer

######################### 4. Module instantiation and generate construct #########################
#### 4.1 Module instantiation ####

# TODO: support this with parameterized modules
# module instance with range not supported
MODULE_INSTANTIATION -> IDENTIFIER _ IDENTIFIER _ %lparen _ LIST_OF_PORT_CONNECTIONS _ %rparen _ %semicolon {%(d) => {return {Type: "module_instantiation", Module: d[0], Identifier: d[2], Connections: d[6]}}%}

# PARAMETER_VALUE_ASSIGNMENT # TODO: support this with parameterized modules

# LIST_OF_PARAMTER_ASSIGNMENT # TODO: support this with parameterized modules

# ORDERED_PARAMETER_ASSIGNMENT
# issie sheet doesn't keep track of order of parameters or ports, hence not implementable though can be refactored for furture 

# NAMED_PARAMETER_ASSIGNMENT
# TODO: support this with parameterized modules

# MODULE_INSTANCE 
# symbol ommitted and built as part of module instantiation grammar
# help to reduce level of AST and better look through in error check and code gen

LIST_OF_PORT_CONNECTIONS ->
        NAMED_PORT_CONNECTION  (_ %comma _ NAMED_PORT_CONNECTION {%(d)=> {return d[3];}%}):* _ {%(d) => {return [d[0]].concat(d[1]);}%}

# ORDERED_PORT_CONNECTION
# issie sheet doesn't keep track of order of parameters or ports, hence not implementable though can be refactored for furture

# TODO: generalize this such it accepts expression, rather than just primary
NAMED_PORT_CONNECTION ->
        %dot _ IDENTIFIER _ %lparen _ MODULE_INSTANTIATION_PRIMARY _ %rparen {% (d) => {return {Type: "named_port_connection", PortId: d[2], Primary: d[6]}}%}

MODULE_INSTANTIATION_PRIMARY #TODO: allow more general type
    -> IDENTIFIER {%function(d) {return {Type: "primary", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bit", BitsStart: d[3], BitsEnd: d[3], Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %colon UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bits", BitsStart: d[3], BitsEnd: d[5], Primary: d[0]};} %}

#### 4.2 Generate construct ####
# TODO


######################### 5. UDP declarartion and instantiation #########################
# not implemented UDP not supported

######################### 6. Behavioral statements #########################
#### 6.1 Continuous assignment statements ####
# TODO: implement this such list of assignment is supported
CONTINUOUS_ASSIGN
    -> %assign _ NET_ASSIGNMENT _ %semicolon {%function(d) {return {Type: "statement", StatementType: "assign", Assignment: d[2], Location: d[0].offset};} %}

# LIST_OF_NET_ASSIGNMENTS

NET_ASSIGNMENT -> NET_LVALUE _ %op_assign _ EXPRESSION {%function(d) {return {Type: "assign", LHS: d[0], RHS: d[4], Location:d[0].Primary.Location};} %}

#### 6.2 Procedural blocks and assignments ####
# INITIAL_CONSTRUCT # not implemented

ALWAYS_CONSTRUCT # TODO: fix bug such empty statement is allowed
    -> %always_comb _ STATEMENT {%function(d) {
        return {Type: "always_construct", AlwaysType: d[0].value, Statement: d[2], ClkLoc: 0, Location: d[0].offset};} %}
    | %always_ff _ %at _ %lparen _ %posedge _ "clk" _ %rparen _ STATEMENT {%function(d) {
        return {Type: "always_construct", AlwaysType: d[0].value, Statement: d[12], ClkLoc: d[8].offset, Location: d[0].offset};} %}

BLOCKING_ASSIGNMENT ->
    OPERATOR_ASSIGNMENT {%function(d) { return {Assignment: {Type: "blocking_assignment", Operator: d[0].Operator, Assignment: d[0].Assignment}, Location:d[0].Location};} %}

# TODO: remove this additional token due to artifact code
OPERATOR_ASSIGNMENT -> VARIABLE_LVALUE _ %op_assign _ EXPRESSION
    {%function(d) { return {Type: "operator_assignment", Operator: d[2].value, Assignment: {Type: "assign", LHS: d[0], RHS: d[4]}, Location: d[2].offset};} %}

NONBLOCKING_ASSIGNMENT ->
    VARIABLE_LVALUE _ %lte _ EXPRESSION #don't need delay or event control [ delay_or_event_control ]
    {%function(d) {return {Assignment: {Type: "nonblocking_assignment", Assignment: {Type: "assign", LHS: d[0], RHS: d[4]}}, Location: d[2].offset};} %}
    
# PROCEDURAL_CONTINUOUS_ASSIGNMENT 
# the assignment in a procedural block and is usually not synthesizable, not implemented

#### 6.3 Paralle and sequential blocks ####
#TODO: add support for block_identifier, and confirm if it is correct for the +
# block item declaration not supported
SEQ_BLOCK
    -> %begin _ STATEMENT:+ %end _ {% function(d) {return{Type: "seq_block", Statements: d[2], Location: d[0].offset}; } %}

#### 6.4 Statements ####
# due to the dangling if-else problem, the grammar is refactored for this part as well as the conditional statement section
# in order to avoid grammar ambiguity

STATEMENT -> COMPLETE_STATEMENT {%id%}
        | INCOMPLETE_CONDITIONAL_STATEMENT {%id%}

COMPLETE_STATEMENT 
    -> COMPLETE_CONDITIONAL_STATEMENT  {%id%}
    | NONBLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject) {
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "<=";
            return {Type: "statement", StatementType: "nonblocking_assignment", NonBlockingAssign: assignment, BlockingAssign: null, SeqBlock: null, Conditional: null, CaseStatement: null, Location: d[0].Location};
        } %}
    | BLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject){
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "=";
            return {Type: "statement", StatementType: "blocking_assignment", NonBlockingAssign: null, BlockingAssign: assignment, SeqBlock: null, Conditional: null,  CaseStatement: null, Location: d[0].Location};
        } %}
    | SEQ_BLOCK {%function(d,l,reject) {return {Type: "statement", StatementType: "seq_block", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: d[0], Conditional: null,  CaseStatement: null, Location: d[0].Location};} %} #change to statements?
    | CASE_STATEMENT {%function(d,l,reject) {return {Type: "statement", StatementType: "case_statement", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: null,  CaseStatement: d[0], Location: d[0].Location};}%}

STATEMENT_OR_NULL
    -> STATEMENT {% id %}
    | %semicolon {% function(d,l,reject) {return null;} %}

#### 6.5 Timing control statements ####
# not implemented, complex timing and event trigger not supported by issie, always block grammar simplified

#### 6.6 conditional statement ####
# incomplete conditional_statement encoperated to address dangling if-else problem

COMPLETE_CONDITIONAL_STATEMENT 
    -> %t_if _ %lparen _ EXPRESSION _ %rparen _ STATEMENT  %t_else _ STATEMENT {% function(d) {
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
    | %t_if _ %lparen _ EXPRESSION _ %rparen _ STATEMENT  %t_else _ INCOMPLETE_CONDITIONAL_STATEMENT {% function(d) {
        let ifStmt = {Type: "ifstmt", Condition: d[4], Statement: d[8], Location: d[0].offset};
        let conditional = {Type: "cond_stmt", IfStatement: ifStmt, ElseStatement: d[11], Location: d[0].offset};
        return {Type: "statement", StatementType: "conditional", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: conditional,  CaseStatement: null, Location: d[0].offset}
    } %}

#### 6.7 Case statements ####
CASE_STATEMENT 
    # casez and casex not supported as issie supports only 2 state variable, refactor to encoperate the default case
    -> %t_case _ %lparen _ EXPRESSION _ %rparen _ (CASE_ITEM {% id %}):+  DEFAULT:? %t_endcase _ {%function(d) { 
        return {Type: "case_statement", Expression: d[4], CaseItems: d[8], Default: d[9], Location: d[0].offset};}%}

# TODO: generalize it such constant expression is accepted
CASE_ITEM
    -> NUMBER  _ (%comma _ NUMBER _ {%function(d){return d[2];}%}):*  %colon _ STATEMENT
        {% function(d) {expr = [d[0]].concat(d[2]); return {Type: "case_item", Expressions: expr, Statement: d[5]};}%}

# the non official grammar for default case only allows default case to be put last of the case
# this eliminates some generality but it is the recommended way of writing verilog for clarity
DEFAULT
    -> %t_default _ %colon _ STATEMENT {% function(d){return d[4];}%}

#### 6.8 Looping statements ####
# not implemented as not always synthesizable

#### 6.9 task enable statements ####
# not implemented

################# 7. Specify Region ##################
# not implemented, out of scope of project

