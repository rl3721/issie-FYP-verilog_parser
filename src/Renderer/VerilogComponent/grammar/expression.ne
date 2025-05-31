@include "./lexer.ne"
@lexer lexer

# this section is quite extended comparing to the official grammar which didn't encoperate order of operation
##### 8. Expressions #####
#### 8.1 Concatenations ####
CONCATENATIONS
    -> %lbrace _ LIST_OF_UNARIES _ %rbrace {%function(d) {return {Type: "concat", Primary: null, Number: null, Expression: d[2], Location: d[2].Location}; } %}

LIST_OF_UNARIES
    -> EXPRESSION _ %comma _ LIST_OF_UNARIES {%function(d) {return {Type: "unary_list", Head : d[0], Tail: d[4], Location: d[0].Location};} %}
    | EXPRESSION {% function(d) {return {Type: "unary_list", Head: d[0], Tail: null, Location: d[0].Location};}  %}

# MULTIPLE_CONCATENATION : TODO implemented this

#### 8.2 Function calls ####
# not implemented

#### Expressions
# TODO: sort out this
CONSTANT_EXPRESSION
    -> EXPRESSION {% function(d) {return{Type: "constant_expression", ConstantExpression: d[0], Location: d[0].Location}} %}

EXPRESSION -> CONDITIONAL {% id %}

CONDITIONAL
    -> LOGICAL_OR _ %question _ CONDITIONAL_RESULT {%function(d) {return {Type: "conditional_cond", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | LOGICAL_OR {% id %}

CONDITIONAL_RESULT
    -> LOGICAL_OR _ %colon _ LOGICAL_OR {%function(d) {return {Type: "conditional_result", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}

LOGICAL_OR
    -> LOGICAL_OR _ %lor _ LOGICAL_AND {%function(d) {return {Type: "logical_OR", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | LOGICAL_AND {% id %}

LOGICAL_AND
    -> LOGICAL_AND _ %land _ BITWISE_OR {%function(d) {return {Type: "logical_AND", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}  
    | BITWISE_OR {% id %}

BITWISE_OR 
    -> BITWISE_OR _ %or _ BITWISE_XOR {%function(d) {return {Type: "bitwise_OR", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | BITWISE_XOR {% id %}

BITWISE_XOR  
    -> BITWISE_XOR _ XOR_XNOR_OPERATOR _ BITWISE_AND {%function(d) {return {Type: "bitwise_XOR", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | BITWISE_AND {% id %}

BITWISE_AND 
    -> BITWISE_AND _ %and _ LOGICAL_SHIFT {%function(d) {return {Type: "bitwise_AND", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | EQUALITY {% id %}

# here put case equality, logical equality, comparison
EQUALITY
    -> EQUALITY _ EQUALITY_OPERATOR _ COMPARISON {%function(d) {return {Type: "equality", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | COMPARISON {% id %}

COMPARISON
    -> COMPARISON _ RELATIONAL_OPERATOR _ LOGICAL_SHIFT {%function(d) {return {Type: "comparison", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | LOGICAL_SHIFT {% id %}

LOGICAL_SHIFT #TODO: check if the first rule can be removed after fixing numbers
    -> LOGICAL_SHIFT _ SHIFT_OPERATOR _ UNSIGNED_REDUCTED {%function(d) {return {Type: "SHIFT", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | LOGICAL_SHIFT _ SHIFT_OPERATOR _ ADDITIVE {%function(d) {return {Type: "SHIFT", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | ADDITIVE {% id %}

    # Used for unsigned numbers (only in logical shifts), arithmetic shifts not implemented as signed number number implemented
    UNSIGNED_REDUCTED 
        -> UNSIGNED_UNARY {%function(d) {return {Type: "unary_unsigned", Unary: d[0], Location: d[0].Location};} %}

    UNSIGNED_UNARY
        -> U_NUMBER {%function(d) {return {Type: "number", Primary: null, Number: d[0], Expression: null, Location: d[0].Location};} %}
    
    U_NUMBER
        -> %unsigned_number {%function(d,l,reject) {return {Type: "number", NumberType: "decimal", Bits: null, Base: null, UnsignedNumber: d[0].value, AllNumber: null, Location: d[0].offset};} %}


ADDITIVE
    -> ADDITIVE _ ADDITIVE_OPERATOR _ MULTIPLICATIVE {%function(d) {return {Type: "additive", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | MULTIPLICATIVE {% id %}

MULTIPLICATIVE
    -> MULTIPLICATIVE _ MULTIPLICATION_OPERATOR _ REDUCTION_OR_NEGATION {%function(d) {return {Type: "multiplicative", Operator:d[2].value, Head: d[0], Tail: d[4], Location: d[2].offset};} %}
    | REDUCTION_OR_NEGATION {% id %}

REDUCTION_OR_NEGATION  # TODO: change such that unary operator not need parenthesis, double check for order of operations
    -> %lparen _ UNARY_OPERATOR _ UNARY _ %rparen {%function(d) {return {Type: "reduction", Operator:d[2].value, Unary: d[4], Location: d[2].offset};} %}
    | %not _ UNARY {%function(d) {return {Type: "negation", Operator: "~", Unary: d[2], Location: d[2].offset};} %}
    | UNARY {%function(d) {return {Type: "unary", Unary: d[0], Location: d[0].Location};} %}

#### 8.4 Primaries ####

UNARY 
    -> PRIMARY {%function(d) {return {Type: "primary", Primary: d[0], Number: null, Expression: d[0].Expression, Location: d[0].Location};} %}
    | NUMBER {%function(d) {return {Type: "number", Primary: null, Number: d[0], Expression: null, Location: d[0].Location};} %}
    | %lparen _ BITWISE_OR _ %rparen {%function(d) {return {Type: "parenthesis", Primary: null, Number: null, Expression: d[2], Location: d[2].Location};} %}
    | CONCATENATIONS {% id %}
    # TODO: multiple concatenation



PRIMARY # TODO: refactor this part such it accepts constant expressions
    -> IDENTIFIER {%function(d) {return {Type: "primary", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0], Location: d[0].Location};} %}
    | IDENTIFIER _ %lbracket _ UNSIGNED_NUMBER _ %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bit", BitsStart: d[4], BitsEnd: d[4], Primary: d[0], Location: d[0].Location};} %}
    | IDENTIFIER _ %lbracket _ UNSIGNED_NUMBER _ %colon _ UNSIGNED_NUMBER _ %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bits", BitsStart: d[4], BitsEnd: d[8], Primary: d[0], Location: d[0].Location};} %}
    | IDENTIFIER _ %lbracket _ EXPRESSION _ %rbracket {%function(d) {return {Type: "primary", PrimaryType: "identifier_bit2", BitsStart: null, BitsEnd: null, Primary: d[0], Expression: d[4], Width:1, Location: d[0].Location};} %}

#### 8.5 Expression left-side values ####

NET_LVALUE
    -> IDENTIFIER {%function(d) {return {Type: "l_value", PrimaryType: "identifier", BitsStart: null, BitsEnd: null, Primary: d[0]};} %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %rbracket 
        {%function(d) {
            let start = {Type: "constant_expression", Location: d[2].offset, 
                ConstantExpression: {Type: "unary", Location: d[2].offset,  
                    Unary:{Type: "number", Location: d[2].offset, 
                        Number: {Type: "number", NumberType: "all", Bits: "32", Base: "'d", AllNumber: d[3], Location: d[2].offset}}}};
            return {Type: "l_value", PrimaryType: "identifier_bit", 
                BitsStart: start, 
                BitsEnd: start, 
                Primary: d[0]};
            } 
        %}
    | IDENTIFIER _ %lbracket UNSIGNED_NUMBER %colon UNSIGNED_NUMBER %rbracket 
        {%function(d){
            let start = {Type: "constant_expression", Location: d[2].offset, 
                ConstantExpression: {Type: "unary", Location: d[2].offset, 
                    Unary:{Type: "number", Location: d[2].offset, 
                        Number: {Type: "number", NumberType: "all", Bits: "32", Base: "'d", AllNumber: d[3], Location: d[2].offset}}}};
            let end = {Type: "constant_expression", Location: d[4].offset, 
                ConstantExpression: {Type: "unary", Location: d[4].offset, 
                    Unary:{Type: "number", Location: d[4].offset, 
                        Number: {Type: "number", NumberType: "all", Bits: "32", Base: "'d", AllNumber: d[5], Location: d[4].offset}}}};
            return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: start, BitsEnd: end, Primary: d[0]};
        }       
        %}
    | IDENTIFIER %Lbracket CONSTANT_EXPRESSION %rbracket 
        {%function(d) {
            return {Type: "l_value", PrimaryType: "identifier_bit", BitsStart: d[2], BitsEnd: d[2], Primary: d[0], Expression: d[2], Width: 1};} 
        %}
    | IDENTIFIER %lbracket CONSTANT_EXPRESSION %colon CONSTANT_EXPRESSION %rbracket 
        {%function(d) {
            return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: d[2], BitsEnd: d[4], Primary: d[0], Width: 1};} 
        %}


VARIABLE_LVALUE -> # TODO: fix this
    NET_LVALUE {% id %}
    | VARIABLE_BITSELECT_L_VALUE {% id %}

VARIABLE_BITSELECT_L_VALUE
    -> IDENTIFIER _ %lbracket EXPRESSION %rbracket {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: null, BitsEnd: null, Primary: d[0], VariableBitSelect: d[3], Width: 1};} %}
    #| IDENTIFIER _ %lbracket EXPRESSION _ %minus _ %colon UNSIGNED_NUMBER %rbracket {%function(d) {return {Type: "l_value", PrimaryType: "identifier_bits", BitsStart: null, BitsEnd: null, Primary: d[0], VariableBitSelect: d[3], Width: parseInt(d[8].value)};} %} 



#### 8.6 Operators ####
EQUALITY_OPERATOR -> %eq {% id %} | %neq {% id %} 

RELATIONAL_OPERATOR -> %lt {% id %} | %lte {% id %} | %gt {% id %} | %gte {% id %} 

ADDITIVE_OPERATOR -> %plus {% id %} | %minus {% id %} 

XOR_XNOR_OPERATOR -> %xor_xnor {% id %} 

SHIFT_OPERATOR -> %sll {% id %} | %srl {% id %} | %sra {% id %} 

UNARY_OPERATOR -> %lnot {% id %}  | %and {% id %}  | %nand {% id %} | %or {% id %} | %nor {% id %} #{%function(d) {return d[0].join('');} %}

MULTIPLICATION_OPERATOR -> %mult {% id %} 

#### 8.7 Numbers ####
   
NUMBER
    -> HEX_NUMBER {% id %}
    | BINARY_NUMBER {% id %}
    # | OCTAL_NUMBER {% id %}
    | DECIMAL_NUMBER {% id %}
    # | real number not implemented

BINARY_NUMBER
    -> %unsigned_number %binary {%function(d,l,reject) {
        let num = d[1].value.slice(2);
        return {Type: "number", NumberType: "all", Bits: d[0].value, Base: "'b", UnsignedNumber: null, AllNumber: num, Location: d[0].offset};
        } %}

HEX_NUMBER
    -> %unsigned_number %hexdecimal {%function(d,l,reject) {
        let num = d[1].value.slice(2);
        return {Type: "number", NumberType: "all", Bits: d[0].value, Base: "'h", UnsignedNumber: null, AllNumber: num, Location: d[0].offset};
        } %}
    # | %hexdecimal {%function(d,l,reject) { 
    #     let num = d[0].value.slice(2);
    #     return {Type: "number", NumberType: "all", Bits: null, Base: "'h", UnsignedNumber: null, AllNumber: num, Location: d[0].offset};
    #     } %}

DECIMAL_NUMBER
    -> %unsigned_number %decimal 
        {%function(d,l,reject) {
        let num = d[1].value.slice(2);
        return {Type: "number", NumberType: "all", Bits: d[0].value, Base: "'d", UnsignedNumber: null, AllNumber: num, Location: d[0].offset};
        } %}
    # | %decimal {%function(d,l,reject) {
    #     let num = d[0].value.slice(2);
    #     return {Type: "number", NumberType: "all", Bits: null, Base: "'d", UnsignedNumber: null, AllNumber: num, Location: d[0].offset};
    #     } %}
    # | %unsigned_number {%function(d,l,reject) {
    #     return {Type: "number", NumberType: "decimal", Bits: null, Base: null, UnsignedNumber: d[0].value, AllNumber: null, Location: d[0].offset};
    #     } %}

# TODO: remove this after sorting constant expression
UNSIGNED_NUMBER -> %unsigned_number {%(d)=>{return d[0].value}%}




##############################################   9. GENERAL    #################################################

# input -> %input {% d=>{return {Location: d[0].offset}} %}
# output -> %output {% d=>{return {Location: d[0].offset}} %}
# parameter -> %parameter {% id %}
# assign -> %assign {% d=>{return {Location: d[0].offset}} %}
# wire -> %wire {% d=>{return {Location: d[0].offset}} %}
# logic -> %bit {% d=>{return {Location: d[0].offset}} %}
# endmodule -> %endmodule {% d=>{return {Location: d[0].offset}} %}
 
# EVERYTHING -> %EVERYTHING

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
# _ -> %ws:+ 


PORT_IDENTIFIER -> IDENTIFIER {%function(d) {return {Type: "port_identifier", Name: d[0], Location: d[0].Location};} %}

MODULE_IDENTIFIER -> IDENTIFIER {% id %}
