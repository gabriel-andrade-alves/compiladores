%{
#include <string>
%}

%option noyywrap
ESPACO [ \t]
DIGITO [0-9]
DIGITOS [1-9]
LETRA [A-Za-z_]

DELIM {ESPACO}+
INT {DIGITO}{DIGITO}*
FLOAT {DIGITO}*"."{DIGITO}+
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
"imp"           {yylval.label = yytext; return TK_IMPRIME; }
"impl"          {yylval.label = yytext; return TK_IMPRIME; }
"ler"           { return TK_LER; }

        /* Tokens condicionais */
"if"            { return TK_IF; }
"else"          { return TK_ELSE; }

        /* Tokens de repetição*/
"while"         {return TK_WHILE; }
"do"            {return TK_DO; }
"for"           {return TK_FOR; }

        /* Controles de laço de repetição */
"break"         { return TK_BREAK; }
"quebra"        { return TK_BREAK; }
"all"           { return TK_ALL; }
"tudo"          { return TK_ALL; }
"continue"      { return TK_CONTINUE; }


        /* Números e identificador */
{FLOAT}         { yylval.label = yytext; return TK_FLOAT; }
{INT}		{ yylval.label = yytext; return TK_INT; }
{ID}		{ yylval.label = yytext; return TK_ID; }


        /* Char*/
{CHAR}          { yylval.label = yytext; return TK_CHAR; }


        /* Atribuição, parênteses e ;  */
"="             {return *yytext; }
";"             {return *yytext; }
","             {return *yytext; }
[(){}]          {return *yytext; }


        /* Operadores aritméticos*/
"+"             { return *yytext; }
"-"             { return *yytext; }
"*"             { return *yytext; }
"/"             { return *yytext; }

        /* Operadores unários */

"++"            { return TK_INC; }
"--"            { return TK_DEC; }


        /* Operadores relacionais*/

">="            {yylval.label = yytext; return TK_REL; }
">"             {yylval.label = yytext; return TK_REL; }
"<="            {yylval.label = yytext; return TK_REL; }
"<"             {yylval.label = yytext; return TK_REL; }
"=="            {return TK_EQ; }
"!="            {return TK_DIF; }



        /* Operadores lógicos*/

"&&"            {return TK_AND; }
"||"            {return TK_OR; }
"!"             {return *yytext; }

        /* Comentario */
"§".*          {}
"//".*          {}



%%