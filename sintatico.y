%{
#include <iostream>
#include <string>
#include <sstream>
#include <fstream>
#include <map>          

using namespace std;


struct atributos
{
	string label;
	string traducao;
};

#define YYSTYPE atributos

int var_temp_qnt;
map<string, string> tabela_simbolos; 

int yylex(void);
void yyerror(string);
string getempcode();
string declaracoes();
%}


%token TK_NUM 
%token TK_ID
%token TK_INT
%token TK_FLOAT

%start S

%left '+' '-'
%left '*' '/'



%%

S           :DECLARACOES COMANDOS  
            {
                cout << "#include <stdio.h>\n"
                     << "int main(){\n"
                     << declaracoes() << "\n"
                     << $2.traducao 
                     << "\treturn 0;\n}" << endl;

            }

DECLARACOES : DECLARACOES DECL
            |

DECL        : TIPO TK_ID ';'
            {
                if(tabela_simbolos.count($2.label))
                    yyerror("Erro: Variável '" + $2.label + "' já declarada.");
                tabela_simbolos[$2.label] = $1.label;
            }


TIPO        : TK_INT    { $$.label = "int"; }
            | TK_FLOAT  { $$.label = "float"; }


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
			| TK_ID '=' E
			{
                if(!tabela_simbolos.count($1.label))
                    yyerror("Erro: Variável '" + $1.label + "' não declarada.");
                
                $$.traducao = $3.traducao + "\tu_" + $1.label + " = " + $3.label + ";\n";
			}
            | TK_NUM 
            {
                $$.label = getempcode();
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
            }
            | TK_ID
            {
                if(!tabela_simbolos.count($1.label))
                    yyerror("Erro: Variável '" + $1.label + "' não declarada.");
                
                $$.label = getempcode();
                $$.traducao = "\t" + $$.label + " = u_" + $1.label + ";\n";
            }
             



%%

#include "lex.yy.c"


string getempcode(){
	var_temp_qnt++;
	return "t" + std::to_string(var_temp_qnt);
}

string declaracoes(){
    string texto = "";

    //adicionar u para diferenciar variavel de usuario de sistema
    for(auto const& [id, tipo] : tabela_simbolos) {
        texto += "\t" + tipo + " u_" + id + "; //user:" + id + "\n";
    }

    for(int i=1; i<=var_temp_qnt; i++){
        texto += "\tint t" + std::to_string(i) + ";\n";
    }
    return texto;
}



int main( int argc, char* argv[] )
{

	var_temp_qnt = 0;

    printf("\n");   
    yyparse();

	return 0;
}

void yyerror( string MSG )
{
	cout << MSG << endl;
	exit (0);
}				
