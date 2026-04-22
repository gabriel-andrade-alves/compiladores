%{
#include <iostream>
#include <string>
#include <sstream>
#include <fstream>

#define YYSTYPE atributos

using namespace std;
int var_temp_qnt;

struct atributos
{
	string label;
	string traducao;
};

int yylex(void);
void yyerror(string);
string getempcode();
string declaracoes();
%}

%token TK_NUM

%start S

%left '+' '-'
%left '*' '/'



%%

S           :COMANDOS  
            {
                cout << "#include <stdio.h>\n" << "int main(){\n" + declaracoes() +
                $1.traducao + "\treturn 0;\n}" << endl;

            }

COMANDOS    : COM COMANDOS
            {
                $$.traducao = $1.traducao + $2.traducao;
            }
            | {$$.traducao = "";}

COM         : E ';'
            ;

E           : '(' E ')'
            {
                $$.label = $2.label;
                $$.traducao = $2.traducao;
            }
            | E '+' E
            {
                $$.label = getempcode();
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" + " + $3.label + ";\n";
            }
            | E '-' E
            {
                $$.label = getempcode();
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" - " + $3.label + ";\n";
            }
            | E '*' E
            {
                $$.label = getempcode();
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" * " + $3.label + ";\n";
            }
            | E '/' E
            {
                $$.label = getempcode();
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" / " + $3.label + ";\n";
            }
            | TK_NUM 
            {
                $$.label = getempcode();
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
            }
             



%%

#include "lex.yy.c"


string getempcode(){
	var_temp_qnt++;
	return "t" + std::to_string(var_temp_qnt);
}

string declaracoes(){
    string texto = "";
    for(int i=1; i<=var_temp_qnt; i++){
        texto += "\tint t" + std::to_string(i) + ";\n";
    }
    return texto;
}



int main( int argc, char* argv[] )
{

	var_temp_qnt = 0;
    
    yyparse();

	return 0;
}

void yyerror( string MSG )
{
	cout << MSG << endl;
	exit (0);
}				
