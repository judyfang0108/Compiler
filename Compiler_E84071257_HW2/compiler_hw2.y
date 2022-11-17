/*	Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* func_sig,int is_param_function);
    static NODE lookup_symbol(char* name, int tables);
    static void dump_symbol(int scope);
    static char* get_type(char* name);
    static int check_literal(char* name,int index);

    /* Global variables */
    bool HAS_ERROR = false;
    int address=0;//current address
    char types[10];//record type
    char op[10];//record opernad
    char func_name[10];//record function name
    int has_param;//whether function has parameter
    char param_type_list[10];//record function's parameters type 
    char return_type[10];//record return type of function
    int level = -1; //current scope index
    int specify_level=-1;//look up specify level
    NODE symbol_table[MAX_LEVEL][MAX_LENGTH]; // symbol table
    int size[MAX_LEVEL]; // each symbol_table len
    NODE *current;//current read in token
    char arr[10][20] = {{"int32"},
                        {"float32"},
                        {"bool"},
                        {"string"},
                        {"NEG"},
                        {"POS"},
                        {"GTR"},
                        {"LSS"},
                        {"NEQ"},
                        {"EQL"} };
%}

//%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token VAR PACKAGE FUNC DEFAULT RETURN
%token INT FLOAT BOOL STRING
%token INC DEC GEQ LEQ EQL NEQ
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token TRUE FALSE

/* Token with return, which need to sepcify type */
%token <s_val> INT_LIT FLOAT_LIT STRING_LIT BOOL_LIT
%token <s_val> IDENT NEWLINE LAND LOR PRINT PRINTLN 
%token <s_val> IF ELSE FOR SWITCH CASE

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Left Type Expression PrimaryExpr Literal Operand IndexExpr ConversionExpr UnaryExpr
%type <s_val> add_op mul_op cmp_op unary_op assign_op
%type <s_val> LandExpr ComparisonExpr AdditionExpr MultiplyExpr 
%type <s_val> PrintStmt AssignmentStmt SimpleStmt ExpressionStmt
%type <s_val> Condition ForStmt SwitchStmt CaseStmt 

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE
    | FunctionDeclStmt
    | NEWLINE
;

PackageStmt
    : PACKAGE IDENT
    {
        create_symbol();
        printf ("package: %s\n",yylval.s_val);
    }
;

FunctionDeclStmt
    : FUNC IDENT
    { 
        has_param=0;
        strcpy(func_name,yylval.s_val);
        strcpy(param_type_list,"(");
        printf ("func: %s\n",func_name);
        create_symbol(); 
    } 
    '('ParameterList {
    	if(has_param==0){
    		printf ("func_signature: ()V\n");
    		insert_symbol(func_name, "func", "()V",0);  
    	}else{
    		strcat(param_type_list,")");
    		
    	} 
    } ')' ReturnType{
    	  if(has_param!=0){
    	  	strcat(param_type_list,return_type);
    	  	printf ("func_signature: %s\n",param_type_list);
    	  	insert_symbol(func_name, "func", param_type_list,0);   
    	  }
    	  
    } FuncBlock
;

FuncBlock
    : '{' { level++; } StatementList '}' { dump_symbol(level); }
;

ReturnType
    : INT {strcpy(return_type,"I");}
    | FLOAT {strcpy(return_type,"F");}
    | STRING 
    | BOOL 
    | 
;

ParameterList
    : Parameter
    | ParameterList ',' Parameter
;

Parameter
    : IDENT Type {
    	has_param=1;
        char type[20];
        char param_type[20];
    	if(strcmp($2,"int32")==0){
    		strcpy(param_type,"I");
    		strcpy(type,"int32");
    		strcat(param_type_list,"I");
    	}
    	else if(strcmp($2,"float32")==0){
    		strcpy(param_type,"F");
    		strcpy(type,"float32");
    		strcat(param_type_list,"F");
    	}
    	printf("param %s, type: %s\n",$1,param_type); 
    	insert_symbol($1, type, "-",1);  
    }
    |
;


CallFunc
    :IDENT '('CallFuncParamlist ')' {
    	specify_level=0;
    	NODE t = lookup_symbol($1, 1);
        if(t.address == -1){
           printf("call: %s%s\n",$1,t.func_sig);
           specify_level=-1;
        }
    } 
;
	
CallFuncParamlist
    : CallFuncParam
    | CallFuncParamlist ',' CallFuncParam
;	

CallFuncParam
    : Left //IDENT Literal
    |     
;
	
StatementList
    : StatementList Statement
    | Statement
;

Type
    : INT {$$ = "int32";}
    | FLOAT {$$ = "float32";}
    | STRING {$$ = "string";}
    | BOOL {$$ = "bool";}
;

Expression 
    : LandExpr
    | Expression LOR LandExpr { //Ex: x>2 || y<3 && z<4
	    $$="bool"; strcpy(types, "bool");
	    if( strcmp($1, "int32")== 0 || strcmp($3, "int32")==0){
		yyerror("invalid operation: (operator LOR not defined on int32)");
	    }
	    if( strcmp($1, "float32")==0 || strcmp($3, "float32")==0 ){
		yyerror("invalid operation: (operator LOR not defined on float32)");
	    }
	    printf("LOR\n"); 
    }
;

LandExpr
    : ComparisonExpr //Ex: x>2
    | LandExpr LAND ComparisonExpr { //Ex: x>2 && y<3 && z<4
	    $$="bool"; strcpy(types, "bool");
	    if( strcmp($1, "int32")== 0 || strcmp($3, "int32")==0){
		yyerror("invalid operation: (operator LAND not defined on int32)");
	    }
	    if( strcmp($1, "float32")==0 || strcmp($3, "float32")==0 ){
		yyerror("invalid operation: (operator LAND not defined on float32)");
	    }
	    printf("LAND\n"); 
    }
;

ComparisonExpr
    : AdditionExpr
    | ComparisonExpr cmp_op AdditionExpr { 
        if (strcmp(get_type($1),"null")==0)
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, "ERROR", types);
        $$=$2; 
        printf("%s\n", $2); strcpy(types, "bool");
    }
;

AdditionExpr
    : MultiplyExpr
    | AdditionExpr add_op MultiplyExpr { 
    if(strcmp(get_type($1),"POS")!= 0 &&  strcmp(get_type($1),"NEG")!=0 && strcmp(get_type($1),"bool") !=0 && strcmp(get_type($1), types) !=0 )
    	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, op, get_type($1), types);
    printf("%s\n", $2); }
;

MultiplyExpr
    : UnaryExpr
    | MultiplyExpr mul_op UnaryExpr { 
        if( strcmp($2, "REM") == 0 )
            if( strcmp(get_type($1), "float32")==0 || strcmp(get_type($3), "float32")==0)
                yyerror("invalid operation: (operator REM not defined on float32)"); 
        printf("%s\n", $2); 
    }
;

UnaryExpr 
    : PrimaryExpr 
    | unary_op UnaryExpr{ printf("%s\n", $1); }
;

cmp_op 
    : EQL { $$ = "EQL"; }
    | NEQ { $$ = "NEQ"; }
    | LEQ { $$ = "LEQ"; }
    | GEQ { $$ = "GEQ"; }
    | '<' { $$ = "LSS"; }
    | '>' { $$ = "GTR"; } 
;

add_op 
    : '+' { $$ = "ADD"; strcpy(op, "ADD"); }
    | '-' { $$ = "SUB"; strcpy(op, "SUB"); }
;

mul_op 
    : '*' { $$ = "MUL"; strcpy(op, "MUL"); }
    | '/' { $$ = "QUO"; strcpy(op, "QUO"); }
    | '%' { $$ = "REM"; strcpy(op, "REM"); }
;

unary_op 
    : '+' { $$ = "POS"; }
    | '-' { $$ = "NEG"; }
    | '!' { $$ = "NOT"; }
;

PrimaryExpr 
    : Operand { $$=$1; }
    | IndexExpr
    | ConversionExpr
;

Operand 
    : Left
    | '(' Expression ')'
;

Literal 
    : INT_LIT { 
    	$$="int32"; printf("INT_LIT %s\n", $1); 
    	strcpy(types, "int32");
    }
    | FLOAT_LIT { 
    	$$="float32"; 
        printf("FLOAT_LIT %f\n", atof($1));
        strcpy(types, "float32");
    } 
    | BOOL_LIT { 
    	$$="bool"; printf("%s\n", $1); strcpy(types, "bool"); 
    }
    | '"' STRING_LIT '"' { 
    	$$="string"; printf("STRING_LIT %s\n", $2); strcpy(types, "string"); 
    }
;

Left
    : Literal { $$=$1;}
    | IDENT { 
    	NODE t = lookup_symbol($1, 1); 
        if( t.address != -1){
            printf("IDENT (name=%s, address=%d)\n", $1, t.address);            
            strcpy(types, t.type);
        }else{
            printf("error:%d: undefined: %s\n", yylineno+1, $1);
        }
    }
;

IndexExpr 
    : PrimaryExpr '[' Expression ']' { strcpy(types, "null");}
;

ConversionExpr 
    : Type '(' Expression ')' {
        if(check_literal($3,4)!=-1){
            printf("%c2%c\n", $3[0], $1[0]);
    	}else{
            NODE t = lookup_symbol($3, 1);
            if(t.address != -1){
                printf("%c2%c\n", t.type[0], $1[0]);
            }
    	}
    	strcpy(types, $1); 
    }
;

Statement 
    : DeclarationStmt NEWLINE
    | SimpleStmt NEWLINE
    | Block 
    | IfStmt 
    | ForStmt 
    | SwitchStmt
    | CaseStmt
    | ReturnStmt NEWLINE
    | PrintStmt NEWLINE
    | FunctionDeclStmt NEWLINE
    | CallFunc
    | NEWLINE
;

DeclarationStmt 
    :VAR IDENT Type '=' Expression { 
     	insert_symbol($2, $3, "-",0); 	
    }
    | VAR IDENT Type {
      	insert_symbol($2, $3, "-",0);  
    }
    | VAR IDENT Type '=' CallFunc {
      	insert_symbol($2, $3, "-",1);  	
    }
;

SimpleStmt 
    : AssignmentStmt 
    | ExpressionStmt 
    | IncDecStmt 
;

Block 
    : '{' { create_symbol(); } StatementList '}' { dump_symbol(level); }
;


IfStmt 
    : IF Condition Block //Ex: If (x>0){}
    | IF Condition Block ELSE IfStmt //Ex: If (x>0){} else if{}
    | IF Condition Block ELSE Block //Ex: If (x>0){} else{}
;

ForStmt 
    : FOR Condition Block //Ex:For (x >0)
    | FOR SimpleStmt ';' Condition ';' SimpleStmt Block { ; } //Ex:For(int i=0;i<0;i++)
;

SwitchStmt
    : SWITCH Expression Block 
;

CaseStmt 
    :  CASE INT_LIT ':' {printf("case %s\n",$<s_val>2);} Block  
    |  DEFAULT ':' Block        
;

PrintStmt 
    : PRINT '(' Expression ')' {
    	if(check_literal($3,4)!=-1){
    		printf("PRINT %s\n", $3);
    	}
    	else{
    		NODE t = lookup_symbol($3, 1);
        	if(t.address == -1){
            		yyerror("print func symbol");
        	}else{
            		printf("PRINT %s\n", t.type);
        	}
    	}
    	strcpy(types, "null");
    }

    | PRINTLN '(' Expression ')' {
    	if(check_literal($3,4)!=-1){
    		printf("PRINTLN %s\n", $3);
    	}
    	else{
    		NODE t = lookup_symbol($3, 1);
        	if(t.address == -1){
            		yyerror("print func symbol");
        	}else{
            		printf("PRINTLN %s\n", t.type);
        	}
    	}
    	strcpy(types, "null");
    }
;


ReturnStmt 
    : RETURN Expression {
    	if(strcmp(return_type,"")==0)
    		printf ("return\n");
    	else if (strcmp(return_type,"I")==0)
    		printf ("ireturn\n");
    	else if (strcmp(return_type,"F")==0)
    		printf ("freturn\n");
    }
    | RETURN {printf ("return\n");}
;


Condition : Expression {
    if(strcmp("null", get_type($1))!=0 )
        if( strcmp("int32", get_type($1)) == 0 || strcmp("float32", get_type($1))== 0  ){
            printf("error:%d: non-bool (type %s) used as for condition\n", yylineno+1, get_type($1));
        }
    } 
;

AssignmentStmt 
    : Left assign_op Expression {
    	if (strcmp(get_type($1),"null")==0)
        	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, "ERROR", types); 
    	if( strcmp(get_type($1), "null")!=0 &&  strcmp(types, "null")!=0 && strcmp(get_type($1), types) != 0){
        	printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, get_type($1), types);
    	}	
    	printf("%s\n", $2);
    }
;

assign_op 
    : '=' { $$="ASSIGN"; }
    | ADD_ASSIGN { $$="ADD"; }
    | SUB_ASSIGN { $$="SUB"; }
    | MUL_ASSIGN { $$="MUL"; }
    | QUO_ASSIGN { $$="QUO"; }
    | REM_ASSIGN { $$="REM"; }
;

ExpressionStmt 
    : Expression 
;

IncDecStmt 
    : Expression INC { printf("INC\n"); }
    | Expression DEC { printf("DEC\n"); }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    current = (NODE*)malloc(sizeof(NODE));

    yylineno = 0;
    yyparse();

    dump_symbol(level);

    printf("Total lines: %d\n", yylineno);
    fclose(yyin);

    return 0;
}

static void create_symbol() {
    level++;
    printf("> Create symbol table (scope level %d)\n", level);
}

static void insert_symbol(char* name, char* type, char* func_sig,int is_param_function) {
    NODE t = lookup_symbol(name, 0);
    
    if(t.address != -1){ //redeclared error, but still need to insert
        printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, name, t.lineno);
    }
    
    /*insert part*/
    if(strcmp(type,"func")==0){//whether its type is function
    	level--;
    	symbol_table[level][size[level]].address = -1;
    	symbol_table[level][size[level]].lineno = yylineno+1;
    	
    }
    else if(is_param_function==1){//whether its a parameter or the value is from calling function
    	symbol_table[level][size[level]].address = address;
    	symbol_table[level][size[level]].lineno = yylineno+1;
    	address++;
    }
    else{
    	symbol_table[level][size[level]].address = address;
    	symbol_table[level][size[level]].lineno = yylineno;
    	address++;
    }
    strcpy(symbol_table[level][size[level]].name, name);
    strcpy(symbol_table[level][size[level]].type, type);
    strcpy(symbol_table[level][size[level]].func_sig, func_sig);
    
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, symbol_table[level][size[level]].address, level);
    size[level]++;
    
}

static NODE lookup_symbol(char* name, int tables) {
    /*specify level*/
    if(specify_level!=-1){
    	for(int j=0; j<size[specify_level]; ++j){
		if(strcmp(symbol_table[specify_level][j].name, name)==0)
			return symbol_table[specify_level][j];
	    }
            NODE node;
            node.address = -1;
            return node;
    }
    /*non specify level*/
    else{
    	if(tables == 0){//curr symbol_table
	    for(int j=0; j<size[level]; ++j){
		if(0 == strcmp(symbol_table[level][j].name, name))
			return symbol_table[level][j];
	    }
            NODE node;
            node.address = -1;
            return node;
    	}
        else{//all symbol_table
            for(int i=level; i>=0; --i){
                for(int j=0; j<size[i]; ++j){
                    if(0 == strcmp(symbol_table[i][j].name, name))
                        return symbol_table[i][j];
                }
            }
            NODE node;
            node.address = -1;
            return node;
        }
    }
    
}

static void dump_symbol(int scope) {
    printf("\n> Dump symbol table (scope level: %d)\n", scope);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
    for(int i=0; i<size[scope]; ++i){
        printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",
            i, symbol_table[scope][i].name, symbol_table[scope][i].type, symbol_table[scope][i].address, symbol_table[scope][i].lineno, symbol_table[scope][i].func_sig);
    }
    size[level] = 0;
    level--;
    printf("\n");
}

static int check_literal(char* name,int index){
    int exist=-1;
    for (int i = 0; i < index; i++) {
        if(strcmp(name, arr[i])==0){
           	exist=i;
            break;
        } 
    }
    return exist;
}

static char* get_type(char* name){
    if (check_literal(name,10)!=-1){
        return name;
    }else{
        *current = lookup_symbol(name, 1);
        if(current->address == -1){
            return "null";
        }else{
            return current->type;
        }
    }
}

