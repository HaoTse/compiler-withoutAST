
%option noinput
%option nounput
%{
#include "header.h"
#include "tok.h"

#define SAVE_TOKEN yylval.str = new string(yytext)
#define PF(s) printf("<%s>\t%s\n", s, yytext)

%}

ID id[A-Z][a-z]*
NUMBER [0-9]+
CHARACTER \".\"
COMMENT "//".*

%%
"int"		{ SAVE_TOKEN; return INT; }
"char"		{ SAVE_TOKEN; return CHAR; }
"return"	{ SAVE_TOKEN; return RETURN; }
"if"		{ SAVE_TOKEN; return IF; }
"else"		{ SAVE_TOKEN; return ELSE; }
"while"		{ SAVE_TOKEN; return WHILE; }
"break"		{ SAVE_TOKEN; return BREAK; }
"print"		{ SAVE_TOKEN; return PRINT; }
"read"		{ SAVE_TOKEN; return READ; }

"="			{ SAVE_TOKEN; return '='; }
"!"			{ SAVE_TOKEN; return '!'; }
"+" 		{ SAVE_TOKEN; return '+'; }
"-"			{ SAVE_TOKEN; return '-'; }
"*"			{ SAVE_TOKEN; return '*'; }
"/"			{ SAVE_TOKEN; return '/'; }

"=="		{ SAVE_TOKEN; return EQ_OP; }
"!="		{ SAVE_TOKEN; return NE_OP; }
"<"			{ SAVE_TOKEN; return LT_OP; }
">"			{ SAVE_TOKEN; return GT_OP; }
"<="		{ SAVE_TOKEN; return LE_OP; }
">="		{ SAVE_TOKEN; return GE_OP; }
"&&"		{ SAVE_TOKEN; return AND_OP; }
"||"		{ SAVE_TOKEN; return OR_OP; }

"["			{ SAVE_TOKEN; return '['; }
"]"			{ SAVE_TOKEN; return ']'; }
"("			{ SAVE_TOKEN; return '('; }
")"			{ SAVE_TOKEN; return ')'; }
"{"			{ SAVE_TOKEN; return '{'; }
"}"			{ SAVE_TOKEN; return '}'; }
";"			{ SAVE_TOKEN; return ';'; }
","			{ SAVE_TOKEN; return ','; }

{ID}		{ SAVE_TOKEN; return ID; }
{NUMBER}	{ SAVE_TOKEN; return NUMBER; }
{CHARACTER}	{ SAVE_TOKEN; return CHARACTER; }
{COMMENT}	{ PF("COMMENT"); }

[ \t]*		{ }
[\n]		{ yylineno++; }

.			{ PF("ERROR"); }
%%
