%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]

DELIM {ESPACO}+
NUM {DIGITO}+


%%

"\n" {}

{DELIM} {}

[+;]		{ return *yytext; }

{NUM}		{ yylval.label = yytext; return TK_NUM; }



%%