@include "./lexer.ne"
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

MODULE_INSTANTIATION_PRIMARY
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
    -> assign _ NET_ASSIGNMENT _ %semicolon {%function(d) {return {Type: "statement", StatementType: "assign", Assignment: d[2], Location: d[0].Location};} %}

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
STATEMENT 
    -> BLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject){
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "=";
            return {Type: "statement", StatementType: "blocking_assignment", NonBlockingAssign: null, BlockingAssign: assignment, SeqBlock: null, Conditional: null,  CaseStatement: null, Location: d[0].Location};
        } %}
    | CASE_STATEMENT {%function(d,l,reject) {return {Type: "statement", StatementType: "case_stmt", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: null, Conditional: null,  CaseStatement: d[0], Location: d[0].Location};}%}
    | INCOMPLETE_CONDITIONAL_STATEMENT {%id%}
    | COMPLETE_CONDITIONAL_STATEMENT  {%id%}
    | NONBLOCKING_ASSIGNMENT _ %semicolon _ 
        {%function(d,l,reject) {
            let assignment = d[0].Assignment;
            assignment.Assignment.Type = "<=";
            return {Type: "statement", StatementType: "nonblocking_assignment", NonBlockingAssign: assignment, BlockingAssign: null, SeqBlock: null, Conditional: null, CaseStatement: null, Location: d[0].Location};
        } %}
    | SEQ_BLOCK {%function(d,l,reject) {return {Type: "statement", StatementType: "seq_block", NonBlockingAssign: null, BlockingAssign: null, SeqBlock: d[0], Conditional: null,  CaseStatement: null, Location: d[0].Location};} %} #change to statements?



CONDITIONAL_STATEMENT ->
    # IF ELSE_IF:* ELSE:? {%function(d) {if_statements=[d[0]].concat(d[1]); return {Type: "cond_stmt", IfStatements: if_statements, ElseStatement: d[2]}}%}
    IF ELSE:? {% function(d) {return {Type: "cond_stmt", IfStatement: d[0], ElseStatement: d[1], Location: d[0].Location};} %}




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
VARIABLE_LVALUE -> 
    NET_LVALUE {% id %}
    | VARIABLE_BITSELECT_L_VALUE {% id %}

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





###########################################      EXPRESSIONS      ###############################################

WIRE_L_VALUE
    -> IDENTIFIER {%function(d) {return {Type: "l_value", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0]};} %}
    | %lbracket UNSIGNED_NUMBER %colon UNSIGNED_NUMBER %rbracket _ IDENTIFIER {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: d[1], BitsEnd: d[3], Primary: d[6]};} %}

NET_LVALUE
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


PORT_IDENTIFIER -> IDENTIFIER {%function(d) {return {Type: "port_identifier", Name: d[0], Location: d[0].Location};} %}




NAME_OF_MODULE -> IDENTIFIER {% id %}
