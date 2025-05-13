# IMPORTANT, the order of the lexer rules matter, it is matched from top to bottom
@{%
const moo = require("moo");

const lexer = moo.compile({
    attributes: {
      match: /\(\*[\s\S]*?\*\)/,
      lineBreaks: true
    },
    nand: '~&',
    nor: '~|',
    sll: '<<',
    srl: '>>',
    sra: '>>>',
    xor_xnor: ["^","~^","^~"],
    gte: '>=',
    lte: '<=',
    lor: '||',
    land: '&&',
    eq: '==',
    neq: '!=',
    //hexBase: "'h",
    //binaryBase: "'b",
    // decimalBase: "'d",
    lparen: '(',
    rparen: ')',
    semicolon: ';',
    comma: ',',
    lbracket: '[',
    rbracket: ']',
    at: '@',
    op_assign: '=',
    colon: ':',
    question: '?',
    or: '|',
    and: '&',
    not: '~',
    lbrace: '{',
    rbrace: '}',
    lt: '<',
    gt: '>',
    plus: '+',
    minus: '-',
    lnot: '!',
    mult: '*',
    dot: '.',
    binary: /\'[bB][0-1]+/,
    unsigned_number: /[0-9]+/,
    octal: /\'[oO][0-7]+/,
    decimal: /\'[dD][0-9]+/,
    hexdecimal: /\'[hH][0-9a-fA-F]+/,
    IDENTIFIER: {match: /[a-zA-Z][a-zA-Z_0-9]*/, type: moo.keywords({
        keywords: ["alias","always", "always_comb", "always_ff", "and","assert","assign","assume","automatic","before","begin","bind","bins","binsof","bit","break","buf","bufif0","bufif1","byte","case","casex","casez","cell","chandle","class","clocking","cmos","config","const","constraint","context","continue","cover","covergroup","coverpoint","cross","deassign","default","defparam","design","disable","dist","do","edge","else","end","endcase","endclass","endclocking","endconfig","endfunction","endgenerate","endgroup","endinterface","endmodule","endpackage","endprimitive","endprogram","endproperty","endsequence","endspecify","endtable","endtask","enum","event","expect","export","extends","extern","final","first_match","for","force","foreach","forever","fork","forkjoin","function","generate","genvar","highz0","highz1","if","iff","ifnone","ignore_bins","illegal_bins","import","incdir","include","initial","inout","input","inside","instance","int","integer","interface","intersect","join","join_any","join_none","large","liblist","library","local","localparam","logic","longint","macromodule","matches","medium","modport","module","nand","negedge","new","nmos","nor","noshowcancelled","not","notif0","notif1","null","or","output","package","packed","parameter","pmos","posedge","primitive","priority","program","property","protected","pull0","pull1","pulldown","pullup","pulsestyle_ondetect","pulsestyle_onevent","pure","rand","randc","randcase","randsequence","rcmos","real","realtime","ref","reg","release","repeat","return","rnmos","rpmos","rtran","rtranif0","rtranif1","scalared","sequence","shortint","shortreal","showcancelled","signed","small","solve","specify","specparam","static","string","strong0","strong1","struct","super","supply0","supply1","table","tagged","task","this","throughout","time","timeprecision","timeunit","tran","tranif0","tranif1","tri","tri0","tri1","triand","trior","trireg","type","typedef","union","unique","unsigned","use","uwire","var","vectored","virtual","void","wait","wait_order","wand","weak0","weak1","while","wildcard","wire","with","within","wor","xnor","xor"],
        module: "module",
        endmodule: "endmodule",
        input: 'input',
        output: 'output',
        //parameter: 'parameter',
        assign: 'assign',
        bit: 'bit',
        always_comb: 'always_comb',
        always_ff: 'always_ff',
        posedge: 'posedge',
        begin: 'begin',
        end: 'end',
        t_if: 'if',
        t_else: 'else',
        t_case: 'case',
        t_endcase: 'endcase',
        t_default: 'default'
      })},
    ws: {match: /[\s]/, lineBreaks: true},
    comment: /\/\/.*$/,  // Single line comment
    comment2: {match: /\/\*[\s\S]*?\*\//, lineBreaks: true},  // Multi-line comment
    directives: /`.*$/,  // Preprocessor directives
    
    EVERYTHING: {match: /./, lineBreaks: true}

});

// Skip whitespace and comments by overriding the `next` method, _ for optional whitespace are kept from artifact
lexer.next = (function (next) {
  return function () {
    let token;
    do {
      token = next.call(this);
    } while (token && (token.type === "ws" || token.type === "comment" || token.type === "comment2" 
    || token.type === "directives" || token.type === "attributes")); // Skip whitespace tokens
    return token;
  };
})(lexer.next);
%}