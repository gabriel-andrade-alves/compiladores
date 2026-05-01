%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
DIGITOS [1-9]
LETRA [A-Za-z_]


DELIM {ESPACO}+
NUM_INT {DIGITOS}{DIGITO}*
NUM_FLOAT {DIGITOS}{DIGITO}*"."{DIGITO}+
ID {LETRA}({LETRA}|{DIGITO})*


%%

"\n" {}

{DELIM} {}

"int"       { return TK_INT; }
"float"     { return TK_FLOAT; }

"imprime"     {return *yytext;}

[()]		{ return *yytext; }

[+\-*/;]	{ return *yytext; }

"="         { return *yytext; }

{ID}		    { yylval.label = yytext; return TK_ID; }
{NUM_INT}		{ yylval.label = yytext; return TK_NUM_INT; }
{NUM_FLOAT}     { yylval.label = yytext; return TK_NUM_FLOAT; }



%%