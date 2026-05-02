%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
DIGITOS [1-9]
LETRA [A-Za-z_]

DELIM {ESPACO}+
INT {DIGITOS}{DIGITO}*
FLOAT {DIGITOS}{DIGITO}*"."{DIGITO}+
ID {LETRA}({LETRA}|{DIGITO})*
CHAR \'(.|\\.)\'

%%

"\n"            {}

{DELIM}         {}

      /* Tipos  */
"int"           { return TK_TIPO_INT; }
"float"         { return TK_TIPO_FLOAT; }
"char"          {return TK_TIPO_CHAR; }
"bool"          {return TK_TIPO_BOOL; }   
"true"          { yylval.label = yytext; return TK_BOOL; }
"false"         { yylval.label = yytext; return TK_BOOL; }

        /* Imprime e leia */
"imprime"       { return TK_IMPRIME; }

        /* Números e identificador */
{FLOAT}     { yylval.label = yytext; return TK_FLOAT; }
{INT}		{ yylval.label = yytext; return TK_INT; }
{ID}		{ yylval.label = yytext; return TK_ID; }


        /* Char*/
{CHAR}          { yylval.label = yytext; return TK_CHAR; }


        /* Atribuição, parênteses e ;  */
"="             {return *yytext; }
";"             {return *yytext; }
[()]            {return *yytext; }


        /* Operadores aritméticos*/
"+"             { return *yytext; }
"-"             { return *yytext; }
"*"             { return *yytext; }
"/"             { return *yytext; }



%%