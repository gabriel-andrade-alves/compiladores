%{
#include <iostream>
#include <string>
#include <sstream>
#include <fstream>
#include <map>        
#include <vector>


using namespace std;


struct atributos
{
	string label;
	string traducao;
    string tipo;
};

struct simbolo
{
    string nome_variavel_sistema;
    string tipo;
};

#define YYSTYPE atributos

int var_temp_qnt;
map<string, simbolo> tabela_simbolos; 
vector<string> tipos_temporarios;


int yylex(void);
void yyerror(string);
string getempcode(string tipo);
string declaracoes();
%}


%token TK_NUM_INT
%token TK_NUM_FLOAT
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
                tabela_simbolos[$2.label] = {"u_" + $2.label, $1.label};
            }


TIPO        : TK_INT    { $$.label = "int"; }
            | TK_FLOAT  { $$.label = "float"; }


COMANDOS    : COM COMANDOS
            {
                $$.traducao = $1.traducao + $2.traducao;
            }
            | {$$.traducao = "";}

COM         : E ';'



E           : 
            /* tipos */
            TK_NUM_INT 
            {
                $$.tipo = "int";
                $$.label = getempcode("int");
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
            }
            | TK_NUM_FLOAT
            {
                $$.label = getempcode("float");
                $$.tipo = "float";
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n"; 
            }
            | TK_ID
            {
                if(!tabela_simbolos.count($1.label))
                    yyerror("Erro: Variável '" + $1.label + "' não declarada.");
                
                $$.tipo = tabela_simbolos[$1.label].tipo;
                $$.label = getempcode(tabela_simbolos[$1.label].tipo);
                $$.traducao = "\t" + $$.label + " = u_" + $1.label + ";\n";
            }


            | '(' E ')'
            {
                $$.label = $2.label;
                $$.tipo = $2.tipo;
                $$.traducao = $2.traducao;
            }


            /* operadores aritmáticos*/
            | E '+' E
            {
                $$.tipo = $1.tipo;
                $$.label = getempcode($$.tipo);
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" + " + $3.label + ";\n";
            }
            | E '-' E
            {
                $$.tipo = $1.tipo;
                $$.label = getempcode($$.tipo);
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" - " + $3.label + ";\n";
            }
            | E '*' E
            {
                $$.tipo = $1.tipo;
                $$.label = getempcode($$.tipo);
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" * " + $3.label + ";\n";
            }
            | E '/' E
            {
                $$.tipo = $1.tipo;
                $$.label = getempcode($$.tipo);
			    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + " = " + $1.label +
				" / " + $3.label + ";\n";
            }
			| TK_ID '=' E
			{
                if(!tabela_simbolos.count($1.label))
                    yyerror("Erro: Variável '" + $1.label + "' não declarada.");
                
                $$.traducao = $3.traducao + "\tu_" + $1.label + " = " + $3.label + ";\n";
			}



        
%%

#include "lex.yy.c"


string getempcode(string tipo){
	var_temp_qnt++;
    tipos_temporarios.push_back(tipo);
	return "t" + std::to_string(var_temp_qnt);
}

string declaracoes(){
    string texto = "";

    //adicionar u para diferenciar variavel de usuario de sistema
    for(auto const& [id, simb] : tabela_simbolos) {
        texto += "\t" + simb.tipo + " " + simb.nome_variavel_sistema + "; //user:" + id + "\n";
        if(simb.tipo == "int")
            texto += "\t" + simb.nome_variavel_sistema + " = 0;\n";
        else if(simb.tipo == "float")
            texto += "\t" + simb.nome_variavel_sistema + " = 0.0;\n";
    }

    //variaveis de sistema 
    for(int i=1; i<=tipos_temporarios.size(); i++){
        texto += "\t" + tipos_temporarios[i-1] + " t" + std::to_string(i) + ";\n";
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
