%{
#include "header.h"
#include "node.h"

extern int yylex(void);
int yyerror(string str);
void AppendMIPS(vector<string> &vec, string _expr);
void MergeMIPS(vector<string> &a, vector<string> &b);
string DecBinoOp(string &op);

Register Reg = Register();
SymbolTable SymTab = SymbolTable();
vector<string>* expr = new vector<string>();
vector<string>* all_instr;
int param_cnt; //count the number of param when call function
string cur_func;
int global_char_cnt = 0; //used to sount aligned
vector<int> cur_if, cur_while;
vector<string> param_tempor;

%}

%union{
	string* str;
	vector<string>* instr;
}

%start Program

%token <str> INT CHAR
%token <str> RETURN IF ELSE
%token <str> WHILE BREAK PRINT READ
%token <str> ID
%token <str> NUMBER
%token <str> CHARACTER
%token <str> '=' '!'

%type <instr> Program DeclList DeclList_ VarDecl_ FunDecl
%type <instr> LocalVarDecl VarDeclList
%type <instr> Block Leave_Block
%type <instr> WHILE_expr IF_expr
%type <instr> StmtList StmtList_ Stmt
%type <str> Expr
%type <instr> ExprListTail
%type <str> Type UnaryOp BinOp

//no function!!!!
%left <str> OR_OP
%left <str> AND_OP
%left <str> EQ_OP NE_OP
%left <str> LT_OP GT_OP LE_OP GE_OP
%left <str> '+' '-'
%left <str> '*' '/'

%%
Program
	: DeclList{
		all_instr = new vector<string>();

		AppendMIPS(*all_instr, "\t.data");
		AppendMIPS(*all_instr, "newLine:\t.asciiz\t\"\\n\"");
		AppendMIPS(*all_instr, "aligned:\t.half\t0");
		AppendMIPS(*all_instr, "\t.text");
		MergeMIPS(*all_instr, *$1);
		
		delete($1);
	}
	;

DeclList
	: DeclList_ DeclList{
		$$ = new vector<string>();

		MergeMIPS(*$$, *$1);
		MergeMIPS(*$$, *$2);

		delete($1);
		delete($2);
	}
	| {
		$$ = new vector<string>();
	}
	;

DeclList_
	: VarDecl_{
		$$ = new vector<string>();

		AppendMIPS(*$$, "\t.data");
		MergeMIPS(*$$, *$1);
		AppendMIPS(*$$, "\t.text");

		delete($1);
	}
	| Type Func_ID FunDecl{ //How to use Type?
		$$ = new vector<string>();
		
		string label = (cur_func == "idMain") ? "main:" : cur_func + ":";
		AppendMIPS(*$$, "# FUNC_" + cur_func + "_BEGIN");
		AppendMIPS(*$$, label);
		
		// save $fp and $ra and $s0 ~ $s7
		AppendMIPS(*$$, "\t# function_in store");
		AppendMIPS(*$$, "\taddi\t$sp,$sp,-4");
		AppendMIPS(*$$, "\tsw\t$30,0($sp)");
		AppendMIPS(*$$, "\taddi\t$sp,$sp,-4");
		AppendMIPS(*$$, "\tsw\t$ra,0($sp)");
		AppendMIPS(*$$, "\taddi\t$sp,$sp,-32");
		AppendMIPS(*$$, "\tsw\t$s0,0($sp)");
		AppendMIPS(*$$, "\tsw\t$s1,4($sp)");
		AppendMIPS(*$$, "\tsw\t$s2,8($sp)");
		AppendMIPS(*$$, "\tsw\t$s3,12($sp)");
		AppendMIPS(*$$, "\tsw\t$s4,16($sp)");
		AppendMIPS(*$$, "\tsw\t$s5,20($sp)");
		AppendMIPS(*$$, "\tsw\t$s6,24($sp)");
		AppendMIPS(*$$, "\tsw\t$s7,28($sp)");
		AppendMIPS(*$$, "\t# end_store\n");

		AppendMIPS(*$$, "\tmove\t$30,$sp");
		
		MergeMIPS(*$$, *$3);

		//AppendMIPS(*$$, "\taddi\t$sp,$sp," + SymTab.GetTotalOffset());
		
		// restore $fp and $ra and $s0 ~ $s7
		AppendMIPS(*$$, "FUNC_" + cur_func + "_END:");
		AppendMIPS(*$$, "\t# function_out restore");
		AppendMIPS(*$$, "\tlw\t$s0,0($sp)");
		AppendMIPS(*$$, "\tlw\t$s1,4($sp)");
		AppendMIPS(*$$, "\tlw\t$s2,8($sp)");
		AppendMIPS(*$$, "\tlw\t$s3,12($sp)");
		AppendMIPS(*$$, "\tlw\t$s4,16($sp)");
		AppendMIPS(*$$, "\tlw\t$s5,20($sp)");
		AppendMIPS(*$$, "\tlw\t$s6,24($sp)");
		AppendMIPS(*$$, "\tlw\t$s7,28($sp)");
		AppendMIPS(*$$, "\taddi\t$sp,$sp,32");
		AppendMIPS(*$$, "\tlw\t$ra,0($sp)");
		AppendMIPS(*$$, "\taddi\t$sp,$sp,4");
		AppendMIPS(*$$, "\tlw\t$30,0($sp)");
		AppendMIPS(*$$, "\taddi\t$sp,$sp,4");
		AppendMIPS(*$$, "\tjr\t$ra");
		AppendMIPS(*$$, "\t# end_restore\n");
		
		delete($1);
	}
	;

Func_ID
	: ID{
		cur_func = *$1;
		delete($1);
	}
	;

VarDecl_
	: Type ID ';'{
		$$ = new vector<string>();

		if(*$1 == "int")
			AppendMIPS(*$$, *$2 + ":\t.word\t4");
		else{
			AppendMIPS(*$$, *$2 + ":\t.asciiz\t\"\"");
			AppendMIPS(*$$, "aligned" + to_string(global_char_cnt++) + ":\t.half\t0");
		}

		//Global variable
		SymTab.Add(*$1, *$2, 0, 1);

		delete($1);
		delete($2);
	}
	| Type ID '[' NUMBER ']' ';'{
		$$ = new vector<string>();
		int size = (*$1 == "int") ? atoi((*$4).c_str()) * 4 : atoi((*$4).c_str());

		AppendMIPS(*$$, *$2 + ":\t.space\t" + to_string(size));

		SymTab.Add(*$1, *$2, 0, atoi((*$4).c_str()));

		delete($1);
		delete($2);
		delete($4);
	}
	;

FunDecl
	: '(' ParamDeclList ')' Block{
		$$ = $4;
	}
	;

ParamDeclList
	: ParamDeclListTail{
		SymTab.InitFuncParam();
	}
	|  {
		SymTab.InitFuncParam();
	}
	;

ParamDeclListTail
	: ParamDecl ParamDeclListTail_
	;

ParamDeclListTail_
	: ',' ParamDeclListTail
	| 
	;

ParamDecl
	: Type ID '[' ']'{
		//Parameter
		SymTab.Add(*$1, *$2, 1, 1);
		
		delete($1);
		delete($2);
	}
	| Type ID{
		SymTab.Add(*$1, *$2, 1, 0);
		
		delete($1);
		delete($2);
	}
	;

LocalVarDecl
	: Type ID ';'{
		$$ = new vector<string>();

		if(*$1 == "int"){
			AppendMIPS(*$$, "\taddi\t$sp,$sp,-4");
		}
		else{
			AppendMIPS(*$$, "\taddi\t$sp,$sp,-4");
		}

		SymTab.Add(*$1, *$2, 2, 1);

		delete($1);
		delete($2);
	}
	| Type ID '[' NUMBER ']' ';'{
		$$ = new vector<string>();
		int size = atoi((*$4).c_str()) * 4;
		
		AppendMIPS(*$$, "\taddi\t$sp,$sp,-" + to_string(size));

		SymTab.Add(*$1, *$2, 2, atoi((*$4).c_str()));

		delete($1);
		delete($2);
		delete($4);
	}
	;

VarDeclList
	: LocalVarDecl VarDeclList{
		$$ = new vector<string>();

		MergeMIPS(*$$, *$1);
		MergeMIPS(*$$, *$2);

		delete($1);
		delete($2);
	}
	|  {
		$$ = new vector<string>();
	}
	;

Block
	: Enter_Block VarDeclList StmtList Leave_Block{
		$$ = new vector<string>();

		AppendMIPS(*$$, "\t# local vaiable declare");
		MergeMIPS(*$$ ,*$2);
		AppendMIPS(*$$, "\t# end_declare\n");
		MergeMIPS(*$$, *$3);
		AppendMIPS(*$$, "\t# end of block\n");
		MergeMIPS(*$$, *$4);

		delete($2);
		delete($3);
		delete($4);
	}
	;

Enter_Block
	: '{'{
		SymTab.EnterScope();
	}
	;

Leave_Block
	: '}'{
		$$ = new vector<string>();

		AppendMIPS(*$$, "\t# flush $sp");
		AppendMIPS(*$$, "\taddi\t$sp,$sp," + SymTab.LeaveScope());
	}
	;

Type
	: INT
	| CHAR
	;

StmtList
	: Stmt StmtList_{
		$$ = new vector<string>();

		MergeMIPS(*$$, *$1);
		MergeMIPS(*$$, *$2);

		delete($1);
		delete($2);
	}
	;

StmtList_
	: StmtList{
		$$ = $1;
	}
	|  {
		$$ = new vector<string>();
	}
	;

Stmt
	: ';'{
		$$ = new vector<string>();
	}
	| Expr ';'{
		$$ = new vector<string>();

		MergeMIPS(*$$, *expr);
		AppendMIPS(*$$, "\n");

		Reg.FreeRegister(*$1);
		delete($1);
		
		(*expr).clear();
	}
	| RETURN Expr ';'{
		$$ = new vector<string>();

		AppendMIPS(*$$, "\t# begin of return value");
		MergeMIPS(*$$, *expr);
		AppendMIPS(*$$, "\tmove\t$v0," + *$2);
		AppendMIPS(*$$, "\t# end of return\n");

		AppendMIPS(*$$, "\t# flush local variables");
		AppendMIPS(*$$, "\taddi\t$sp,$sp," + SymTab.GetOffset());
		
		AppendMIPS(*$$, "\tj\tFUNC_" + cur_func + "_END");

		Reg.FreeRegister(*$2);
		delete($1);
		delete($2);

		(*expr).clear();
	}
	| BREAK ';'{
		$$ = new vector<string>();
		int while_num = cur_while[cur_while.size() - 1];

		AppendMIPS(*$$, "\t# flush of break loop" + to_string(while_num));
		AppendMIPS(*$$, "\taddi\t$sp,$sp," + SymTab.GetBreakOffset());
		AppendMIPS(*$$, "\tb\tendloop" + to_string(while_num));

		delete($1);
	}
	| IF '(' IF_expr ')' Stmt ELSE Stmt{
		$$ = new vector<string>();
		int if_num = cur_if[cur_if.size() - 1];
		cur_if.erase(cur_if.end() - 1);

		AppendMIPS(*$$, "\t# begin of branch" + to_string(if_num));
		MergeMIPS(*$$, *$3);
		AppendMIPS(*$$, "if" + to_string(if_num) + ":");
		MergeMIPS(*$$, *$5);
		AppendMIPS(*$$, "\tb\tendif" + to_string(if_num));
		AppendMIPS(*$$, "else" + to_string(if_num) + ":");
		MergeMIPS(*$$, *$7);
		AppendMIPS(*$$, "\tb\tendif" + to_string(if_num));
		AppendMIPS(*$$, "endif" + to_string(if_num) + ":");
		AppendMIPS(*$$, "\t# end of branch" + to_string(if_num) + "\n");

		delete($1);
		delete($3);
		delete($5);
		delete($6);
		delete($7);

		(*expr).clear();
	}
	| WHILE '(' WHILE_expr ')' Stmt{
		$$ = new vector<string>();
		int while_num = cur_while[cur_while.size() - 1];
		cur_while.erase(cur_while.end() - 1);

		AppendMIPS(*$$, "\t# begin of loop" + to_string(while_num));
		AppendMIPS(*$$, "loop" + to_string(while_num) + ":");
		MergeMIPS(*$$, *$3);
		MergeMIPS(*$$, *$5);
		AppendMIPS(*$$, "\tb\tloop" + to_string(while_num));
		AppendMIPS(*$$, "endloop" + to_string(while_num) + ":");
		AppendMIPS(*$$, "\t# end of loop" + to_string(while_num) + "\n");

		delete($1);
		delete($3);
		delete($5);

		SymTab.LeaveWhile();
	}
	| Block{ $$ = $1; }
	| PRINT ID ';' {
		$$ = new vector<string>();
		Attribute attr;
		
		AppendMIPS(*$$, "\t# begin of print");
		//store $a0
		AppendMIPS(*$$, "\taddi\t$sp,$sp,-4");
		AppendMIPS(*$$, "\tsw\t$a0,0($sp)");

		attr = SymTab.Lookup(*$2);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();
			
			AppendMIPS(*$$, "\tla\t" + tmp_addr + "," + *$2);	
			AppendMIPS(*$$, "\tlw\t$a0,0(" + tmp_addr + ")");
			AppendMIPS(*$$, "\tli\t$v0,1");
			AppendMIPS(*$$, "\tsyscall");

			Reg.FreeRegister(tmp_addr);
		}
		else if(attr.scope == 1){
			AppendMIPS(*$$, "\tmove\t$a0,$a" + to_string(attr.offset));
			AppendMIPS(*$$, "\tli\t$v0,1");
			AppendMIPS(*$$, "\tsyscall");
		}
		else{
			AppendMIPS(*$$, "\tlw\t$a0," + to_string(attr.offset) + "($30)");
			AppendMIPS(*$$, "\tli\t$v0,1");
			AppendMIPS(*$$, "\tsyscall");
		}
		
		//print newline
		AppendMIPS(*$$, "\tla\t$a0,newLine");
		AppendMIPS(*$$, "\tli\t$v0,4");
		AppendMIPS(*$$, "\tsyscall");

		//recover $a0
		AppendMIPS(*$$, "\tlw\t$a0,0($sp)");
		AppendMIPS(*$$, "\taddi\t$sp,$sp,4");
		AppendMIPS(*$$, "\t# end of print\n");

		delete($1);
		delete($2);
	}
	| READ ID ';'{
		$$ = new vector<string>();
		Attribute attr;
		
		AppendMIPS(*$$, "\t# begin of read");
		attr = SymTab.Lookup(*$2);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();
			
			AppendMIPS(*$$, "\tli\t$v0,5");
			AppendMIPS(*$$, "\tsyscall");
			AppendMIPS(*$$, "\tla\t" + tmp_addr + "," + *$2);
			AppendMIPS(*$$, "\tsw\t$v0,0(" + tmp_addr + ")");

			Reg.FreeRegister(tmp_addr);
		}
		else if(attr.scope == 1){
			AppendMIPS(*$$, "\tli\t$v0,5");
			AppendMIPS(*$$, "\tsyscall");
			AppendMIPS(*$$, "\tmove\t$a" + to_string(attr.offset) + ",$v0");
		}
		else{
			AppendMIPS(*$$, "\tli\t$v0,5");
			AppendMIPS(*$$, "\tsyscall");
			AppendMIPS(*$$, "\tsw\t$v0," + to_string(attr.offset) + "($30)");
		}
		AppendMIPS(*$$, "\t# end of read\n");

		delete($1);
		delete($2);
	}
	;

IF_expr
	: Expr{
		$$ = new vector<string>();

		MergeMIPS(*$$, *expr);
		AppendMIPS(*$$, "\tbeq\t" + *$1 + ",$zero,else" + to_string(SymTab.branch_cnt));

		Reg.FreeRegister(*$1);
		delete($1);
		(*expr).clear();
		cur_if.push_back(SymTab.branch_cnt++);
	}
	;

WHILE_expr
	: Expr{
		$$ = new vector<string>();

		// count the offset after enter while
		SymTab.EnterWhile();

		MergeMIPS(*$$, *expr);
		AppendMIPS(*$$, "\tbeq\t" + *$1 + ",$zero,endloop" + to_string(SymTab.loop_cnt));

		Reg.FreeRegister(*$1);
		delete($1);
		(*expr).clear();
		cur_while.push_back(SymTab.loop_cnt++);
	}
	;

Expr
	: UnaryOp Expr{
		$$ = new string(Reg.GetFreeRegister());
		string buf;
		
		if(*$1 == "-")
			buf = "\tsub\t" + *$$ + "," + "$zero" + "," + *$2;
		else{
			AppendMIPS(*expr, "\tsne\t" + *$$ + "," + *$2 + ",$zero");
			buf = "\txori\t" + *$$ + "," + *$$ + ",1";
		}
		AppendMIPS(*expr, buf);
		
		Reg.FreeRegister(*$2);
		delete($1);
		delete($2);
	}
	| NUMBER BinOp Expr{
		$$ = new string(Reg.GetFreeRegister());
		string buf, num_tmp, num_buf;

		//load number to temp
		num_tmp = Reg.GetFreeRegister();
		num_buf = "\tli\t" + num_tmp + "," + *$1;
		AppendMIPS(*expr, num_buf);

		if(*$2 == "&&" || *$2 == "||"){
			AppendMIPS(*expr, "\tsne\t" + *$3 + "," + *$3 + ",$zero");
		}
		buf = DecBinoOp(*$2) + *$$ + "," + num_tmp + "," + *$3;
		AppendMIPS(*expr, buf);

		Reg.FreeRegister(num_tmp);
		Reg.FreeRegister(*$3);
		delete($1);
		delete($2);
		delete($3);
	}
	| NUMBER{
		$$ = new string(Reg.GetFreeRegister());

		AppendMIPS(*expr, "\tli\t" + *$$ + "," + *$1);
		
		delete($1);
	}
	| '(' Expr ')' BinOp Expr{
		$$ = new string(Reg.GetFreeRegister());
		string buf;

		if(*$4 == "&&" || *$4 == "||"){
			AppendMIPS(*expr, "\tsne\t" + *$2 + "," + *$2 + ",$zero");
			AppendMIPS(*expr, "\tsne\t" + *$5 + "," + *$5 + ",$zero");
		}
		buf = DecBinoOp(*$4) + *$$ + "," + *$2 + "," + *$5;
		AppendMIPS(*expr, buf);

		Reg.FreeRegister(*$2);
		Reg.FreeRegister(*$5);
		delete($2);
		delete($4);
		delete($5);
	}
	| '(' Expr ')'{ $$ = $2; }
	| ID BinOp Expr{
		$$ = new string(Reg.GetFreeRegister());
		string buf;
		Attribute attr;
		
		attr = SymTab.Lookup(*$1);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();
			string tmp = Reg.GetFreeRegister();

			AppendMIPS(*expr, "\tla\t" + tmp_addr + "," + *$1);
			AppendMIPS(*expr, "\tlw\t" + tmp + ",0(" + tmp_addr + ")");
			if(*$2 == "&&" || *$2 == "||"){
				AppendMIPS(*expr, "\tsne\t" + tmp + "," + tmp + ",$zero");
				AppendMIPS(*expr, "\tsne\t" + *$3 + "," + *$3 + ",$zero");
			}
			buf = DecBinoOp(*$2) + *$$ + "," + tmp + "," + *$3;
			AppendMIPS(*expr, buf);

			Reg.FreeRegister(tmp_addr);
			Reg.FreeRegister(tmp);
		}
		else if(attr.scope == 1){
			string src = "$a" + to_string(attr.offset);

			if(*$2 == "&&" || *$2 == "||"){
				AppendMIPS(*expr, "\tsne\t" + src + "," + src + ",$zero");
				AppendMIPS(*expr, "\tsne\t" + *$3 + "," + *$3 + ",$zero");
			}
			buf = DecBinoOp(*$2) + *$$ + "," + src + "," + *$3;
			AppendMIPS(*expr, buf);
		}
		else{
			string tmp = Reg.GetFreeRegister();
			string src = to_string(attr.offset) + "($30)";

			AppendMIPS(*expr, "\tlw\t" + tmp + "," + src);
			if(*$2 == "&&" || *$2 == "||"){
				AppendMIPS(*expr, "\tsne\t" + tmp + "," + tmp + ",$zero");
				AppendMIPS(*expr, "\tsne\t" + *$3 + "," + *$3 + ",$zero");
			}
			buf = DecBinoOp(*$2) + *$$ + "," + tmp + "," + *$3;
			AppendMIPS(*expr, buf);
			
			Reg.FreeRegister(tmp);
		}

		Reg.FreeRegister(*$3);
		delete($1);
		delete($2);
		delete($3);
	}
	| ID Enter_Func ExprList ')' BinOp Expr{
		$$ = new string(Reg.GetFreeRegister());
		string buf;

		AppendMIPS(*expr, "\t# call function");
		AppendMIPS(*expr, "\tjal\t" + *$1);

		AppendMIPS(*expr, "\t# restore $t0~$t9 and $a0~$a4");
		AppendMIPS(*expr, "\tlw\t$a0,0($sp)");
		AppendMIPS(*expr, "\tlw\t$a1,4($sp)");
		AppendMIPS(*expr, "\tlw\t$a2,8($sp)");
		AppendMIPS(*expr, "\tlw\t$a3,12($sp)");
		AppendMIPS(*expr, "\tlw\t$t0,16($sp)");
		AppendMIPS(*expr, "\tlw\t$t1,20($sp)");
		AppendMIPS(*expr, "\tlw\t$t2,24($sp)");
		AppendMIPS(*expr, "\tlw\t$t3,28($sp)");
		AppendMIPS(*expr, "\tlw\t$t4,32($sp)");
		AppendMIPS(*expr, "\tlw\t$t5,36($sp)");
		AppendMIPS(*expr, "\tlw\t$t6,40($sp)");
		AppendMIPS(*expr, "\tlw\t$t7,44($sp)");
		AppendMIPS(*expr, "\tlw\t$t8,48($sp)");
		AppendMIPS(*expr, "\tlw\t$t9,52($sp)");
		AppendMIPS(*expr, "\taddi\t$sp,$sp,56");
	    
		AppendMIPS(*expr, "\t# assign return value");
		if(*$5 == "&&" || *$5 == "||"){
			AppendMIPS(*expr, "\tsne\t$v0,$v0,$zero");
			AppendMIPS(*expr, "\tsne\t" + *$6 + "," + *$6 + ",$zero");
		}
		buf = DecBinoOp(*$5) + *$$ + ",$v0," + *$6;
		AppendMIPS(*expr, buf);
		
		AppendMIPS(*expr, "\t# end of call function\n");

		Reg.FreeRegister(*$6);
		delete($1);
		delete($5);
		delete($6);
	}
	| ID Enter_Func ExprList ')'{
		$$ = new string(Reg.GetFreeRegister());

		AppendMIPS(*expr, "\t# call function");
		AppendMIPS(*expr, "\tjal\t" + *$1);

		AppendMIPS(*expr, "\t# restore $t0~$t9 and $a0~$a4");
		AppendMIPS(*expr, "\tlw\t$a0,0($sp)");
		AppendMIPS(*expr, "\tlw\t$a1,4($sp)");
		AppendMIPS(*expr, "\tlw\t$a2,8($sp)");
		AppendMIPS(*expr, "\tlw\t$a3,12($sp)");
		AppendMIPS(*expr, "\tlw\t$t0,16($sp)");
		AppendMIPS(*expr, "\tlw\t$t1,20($sp)");
		AppendMIPS(*expr, "\tlw\t$t2,24($sp)");
		AppendMIPS(*expr, "\tlw\t$t3,28($sp)");
		AppendMIPS(*expr, "\tlw\t$t4,32($sp)");
		AppendMIPS(*expr, "\tlw\t$t5,36($sp)");
		AppendMIPS(*expr, "\tlw\t$t6,40($sp)");
		AppendMIPS(*expr, "\tlw\t$t7,44($sp)");
		AppendMIPS(*expr, "\tlw\t$t8,48($sp)");
		AppendMIPS(*expr, "\tlw\t$t9,52($sp)");
		AppendMIPS(*expr, "\taddi\t$sp,$sp,56");

		AppendMIPS(*expr, "\t# assign return value");
		AppendMIPS(*expr, "\tmove\t" + *$$ + ",$v0");
		AppendMIPS(*expr, "\t# end of call function\n");

		delete($1);
	}
	| ID '[' Expr ']' BinOp Expr{
		$$ = new string(Reg.GetFreeRegister());
		string tmp_i = Reg.GetFreeRegister();
		string buf;
		Attribute attr;
		
		AppendMIPS(*expr, "\tsll\t" + tmp_i + "," + *$3 + ",2");
		attr = SymTab.Lookup(*$1);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();
			
			AppendMIPS(*expr, "\tla\t" + tmp_addr + "," + *$1);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp_addr);
			AppendMIPS(*expr, "\tlw\t" + tmp_addr + ",0(" + tmp_i + ")");
			if(*$5 == "&&" || *$5 == "||"){
				AppendMIPS(*expr, "\tsne\t" + tmp_addr + "," + tmp_addr + ",$zero");
				AppendMIPS(*expr, "\tsne\t" + *$6 + "," + *$6 + ",$zero");
			}
			buf = DecBinoOp(*$5) + *$$ + "," + tmp_addr + "," + *$6;
			AppendMIPS(*expr, buf);

			Reg.FreeRegister(tmp_addr);
		}
		else if(attr.scope == 1){ //unused
			string src = "$a" + to_string(attr.offset);
			string tmp = Reg.GetFreeRegister();
			
			AppendMIPS(*expr, "\tla\t" + tmp + "," + src);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp);
			AppendMIPS(*expr, "\tlw\t" + tmp + ",0(" + tmp_i + ")");
			if(*$5 == "&&" || *$5 == "||"){
				AppendMIPS(*expr, "\tsne\t" + tmp + "," + tmp + ",$zero");
				AppendMIPS(*expr, "\tsne\t" + *$6 + "," + *$6 + ",$zero");
			}
			buf = DecBinoOp(*$5) + *$$ + "," + tmp + "," + *$6;
			AppendMIPS(*expr, buf);

			Reg.FreeRegister(tmp);
		}
		else{
			string tmp = Reg.GetFreeRegister();
			string src = to_string(attr.offset) + "($30)";

			AppendMIPS(*expr, "\tla\t" + tmp + "," + src);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp);
			AppendMIPS(*expr, "\tlw\t" + tmp + ",0(" + tmp_i + ")");
			if(*$5 == "&&" || *$5 == "||"){
				AppendMIPS(*expr, "\tsne\t" + tmp + "," + tmp + ",$zero");
				AppendMIPS(*expr, "\tsne\t" + *$6 + "," + *$6 + ",$zero");
			}
			buf = DecBinoOp(*$5) + *$$ + "," + tmp + "," + *$6;
			AppendMIPS(*expr, buf);

			Reg.FreeRegister(tmp);
		}

		Reg.FreeRegister(tmp_i);
		Reg.FreeRegister(*$3);
		Reg.FreeRegister(*$6);
		delete($1);
		delete($3);
		delete($5);
		delete($6);
	}
	| ID '[' Expr ']' '=' Expr{
		$$ = new string(Reg.GetFreeRegister());
		string tmp_i = Reg.GetFreeRegister();
		Attribute attr;
		
		AppendMIPS(*expr, "\tsll\t" + tmp_i + "," + *$3 + ",2");
		attr = SymTab.Lookup(*$1);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();
			
			AppendMIPS(*expr, "\tla\t" + tmp_addr + "," + *$1);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp_addr);
			AppendMIPS(*expr, "\tsw\t" + *$6 + ",0(" + tmp_i + ")");

			Reg.FreeRegister(tmp_addr);
		}
		else if(attr.scope == 1){ //unused
			string src = "$a" + to_string(attr.offset);
			string tmp = Reg.GetFreeRegister();
			
			AppendMIPS(*expr, "\tla\t" + tmp + "," + src);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp);
			AppendMIPS(*expr, "\tsw\t" + *$6 + ",0(" + tmp_i + ")");

			Reg.FreeRegister(tmp);
		}
		else{
			string tmp = Reg.GetFreeRegister();
			string src = to_string(attr.offset) + "($30)";

			AppendMIPS(*expr, "\tla\t" + tmp + "," + src);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp);
			AppendMIPS(*expr, "\tsw\t" + *$6 + ",0(" + tmp_i + ")");

			Reg.FreeRegister(tmp);
		}
		AppendMIPS(*expr, "\tmove\t" + *$$ + "," + *$6);

		Reg.FreeRegister(tmp_i);
		Reg.FreeRegister(*$3);
		Reg.FreeRegister(*$6);
		delete($1);
		delete($3);
		delete($6);
	}
	| ID '[' Expr ']'{
		$$ = new string(Reg.GetFreeRegister());
		string tmp_i = Reg.GetFreeRegister();
		Attribute attr;
		
		AppendMIPS(*expr, "\tsll\t" + tmp_i + "," + *$3 + ",2");
		attr = SymTab.Lookup(*$1);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();
			
			AppendMIPS(*expr, "\tla\t" + tmp_addr + "," + *$1);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp_addr);
			AppendMIPS(*expr, "\tlw\t" + *$$ + ",0(" + tmp_i + ")");

			Reg.FreeRegister(tmp_addr);
		}
		else if(attr.scope == 1){ //unused
			string src = "$a" + to_string(attr.offset);
			string tmp = Reg.GetFreeRegister();
			
			AppendMIPS(*expr, "\tla\t" + tmp + "," + src);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp);
			AppendMIPS(*expr, "\tlw\t" + *$$ + ",0(" + tmp_i + ")");

			Reg.FreeRegister(tmp);
		}
		else{
			string tmp = Reg.GetFreeRegister();
			string src = to_string(attr.offset) + "($30)";

			AppendMIPS(*expr, "\tla\t" + tmp + "," + src);
			AppendMIPS(*expr, "\tadd\t" + tmp_i + "," + tmp_i + "," + tmp);
			AppendMIPS(*expr, "\tlw\t" + *$$ + ",0(" + tmp_i + ")");

			Reg.FreeRegister(tmp);
		}

		Reg.FreeRegister(tmp_i);
		Reg.FreeRegister(*$3);
		delete($1);
		delete($3);
	} 
	| ID '=' Expr{
		$$ = new string(Reg.GetFreeRegister());
		Attribute attr;

		attr = SymTab.Lookup(*$1);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();

			AppendMIPS(*expr, "\tla\t" + tmp_addr + "," + *$1);
			AppendMIPS(*expr, "\tsw\t" + *$3 + ",0(" + tmp_addr + ")");

			Reg.FreeRegister(tmp_addr);
		}
		else if(attr.scope == 1){
			string src = "$a" + to_string(attr.offset);

			AppendMIPS(*expr, "\tmove\t" + src + "," + *$3);
		}
		else{
			string src = to_string(attr.offset) + "($30)";

			AppendMIPS(*expr, "\tsw\t" + *$3 + "," + src);
		}
		AppendMIPS(*expr, "\tmove\t" + *$$ + "," + *$3);

		Reg.FreeRegister(*$3);
		delete($1);
		delete($3);
	}
	| ID{
		$$ = new string(Reg.GetFreeRegister());
		Attribute attr;
		
		attr = SymTab.Lookup(*$1);
		if(attr.scope == 0){
			string tmp_addr = Reg.GetFreeRegister();

			AppendMIPS(*expr, "\tla\t" + tmp_addr + "," + *$1);
			AppendMIPS(*expr, "\tlw\t" + *$$ + ",0(" + tmp_addr + ")");

			Reg.FreeRegister(tmp_addr);
		}
		else if(attr.scope == 1){
			string src = "$a" + to_string(attr.offset);

			AppendMIPS(*expr, "\tmove\t" + *$$ + "," + src);
		}
		else{
			string src = to_string(attr.offset) + "($30)";

			AppendMIPS(*expr, "\tlw\t" + *$$ + "," + src);\
		}
		
		delete($1);
	}
	;

Enter_Func
	: '('{
		AppendMIPS(*expr, "\t# begin of function call");
		AppendMIPS(*expr, "\tadd\t$sp,$sp, -56");
		AppendMIPS(*expr, "\tsw\t$a0,0($sp)");
		AppendMIPS(*expr, "\tsw\t$a1,4($sp)");
		AppendMIPS(*expr, "\tsw\t$a2,8($sp)");
		AppendMIPS(*expr, "\tsw\t$a3,12($sp)");
		AppendMIPS(*expr, "\tsw\t$t0,16($sp)");
		AppendMIPS(*expr, "\tsw\t$t1,20($sp)");
		AppendMIPS(*expr, "\tsw\t$t2,24($sp)");
		AppendMIPS(*expr, "\tsw\t$t3,28($sp)");
		AppendMIPS(*expr, "\tsw\t$t4,32($sp)");
		AppendMIPS(*expr, "\tsw\t$t5,36($sp)");
		AppendMIPS(*expr, "\tsw\t$t6,40($sp)");
		AppendMIPS(*expr, "\tsw\t$t7,44($sp)");
		AppendMIPS(*expr, "\tsw\t$t8,48($sp)");
		AppendMIPS(*expr, "\tsw\t$t9,52($sp)");
	}
	;

ExprList
	: ExprListTail{

		MergeMIPS(*expr, *$1);

		delete($1);

		for(auto tempor:param_tempor){
			Reg.FreeRegister(tempor);
		}
		param_tempor.clear();

		param_cnt = 0;
	}
	|  {
		param_cnt = 0;
	}
	;

ExprListTail
	: ExprListTail ',' Expr{
		$$ = new vector<string>();
		
		MergeMIPS(*$$, *$1);
		AppendMIPS(*$$, "\tmove\t$a" + to_string(param_cnt++) + "," + *$3);

		param_tempor.push_back(*$3);
		delete($1);
		delete($3);
	}
	| Expr{
		$$ = new vector<string>();

		AppendMIPS(*$$, "\tmove\t$a" + to_string(param_cnt++) + "," + *$1);

		param_tempor.push_back(*$1);
		delete($1);
	}
	;

UnaryOp
	: '-'
	| '!'
	;

BinOp
	: '+'
	| '-'
	| '*'
	| '/'
	| EQ_OP
	| NE_OP
	| LT_OP
	| LE_OP
	| GT_OP
	| GE_OP
	| AND_OP
	| OR_OP
	;
%%

int main(){

	fstream fp;
	fp.open("output.asm", ios::out);

	yyparse();

	for(auto str:(*all_instr)){
		fp << str << endl;
	}

	fp.close();

	return 0;
}

void AppendMIPS(vector<string> &vec, string _expr){
	vec.push_back(_expr);
}

void MergeMIPS(vector<string> &a, vector<string> &b){
	a.insert(a.end(), b.begin(), b.end());
}

string DecBinoOp(string &op){
	if(op == "+")
		return "\tadd\t";
	else if(op == "-")
		return "\tsub\t";
	else if(op == "*")
		return "\tmul\t";
	else if(op == "/")
		return "\tdiv\t";
	else if(op == "==")
		return "\tseq\t";
	else if(op == "!=")
		return "\tsne\t";
	else if(op == "<")
		return "\tslt\t";
	else if(op == "<=")
		return "\tsle\t";
	else if(op == ">")
		return "\tsgt\t";
	else if(op == ">=")
		return "\tsge\t";
	else if(op == "&&")
		return "\tand\t";
	else
		return "\tor\t";
}

int yyerror(string s) {
	extern int yylineno;
	extern char **yytext;

	cerr << "ERROR: " << s << " at symbol \"" << yytext;
	cerr << "\" on line " << yylineno << endl;

	return -1;
}
