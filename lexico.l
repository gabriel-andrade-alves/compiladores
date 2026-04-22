%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA [A-Za-z_]

DELIM {ESPACO}+
NUM {DIGITO}+
ID {LETRA}({LETRA}|{NUM})*


%%

"\n" {}

{DELIM} {}

[()]		{ return *yytext; }

[+\-*/;]	{ return *yytext; }

"="         { return *yytext; }

{ID}		{ yylval.label = yytext; return TK_ID; }
{NUM}		{ yylval.label = yytext; return TK_NUM; }



%%