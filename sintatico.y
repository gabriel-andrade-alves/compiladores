%{
#include <iostream>
#include <string>
#include <sstream>
#include <fstream>
#include <unordered_map>    
#include <vector>

using namespace std;
#define YYSTYPE atributos

struct atributos
{
	string label;
	string traducao;
    string tipo;
};

struct simbolo
{
    string label;
    string tipo;
};


int var_temp_qnt;
string codigo_gerado;
vector<string> tipos_temporarios;
unordered_map<string, simbolo> tabela_simbolos; 


int yylex(void);
int yyerror(string);
string getempcode(string tipo);
string gerar_declaracoes();
void declarar_variavel(string nome, string tipo);
simbolo buscar_simbolo(string nome);
string aplicar_coercao(atributos &e1, atributos &e2, string &label_out1, string &label_out2, string &tipo_res);
%}


//Literais
%token TK_INT
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOL


//Tipos
%token TK_TIPO_INT
%token TK_TIPO_FLOAT
%token TK_TIPO_CHAR
%token TK_TIPO_BOOL


//Identificador
%token TK_ID


// Precedência
%left TK_OR
%left TK_AND
%left TK_EQ TK_DIF
%left '>' '<' TK_GE TK_LE 
%left '+' '-'
%left '*' '/'
%right CAST_PREC
%right '!'


//comandos
%token TK_IMPRIME


%start S


%%

S                   : PROGRAMA
                    {
                        codigo_gerado = codigo_gerado
                                        + "#include <stdio.h>\n" 
                                        + "#define true 1\n"
                                        + "#define false 0\n"
                                        + "#define bool int\n\n"
                                        + "int main(){\n"
                                        + gerar_declaracoes() + "\n"
                                        + $1.traducao
                                        + "\n\treturn 0;\n}\n";
                    }

PROGRAMA            : COMANDOS


COMANDOS            : COMANDOS CMD
                    {
                        $$.traducao = $1.traducao + $2.traducao;
                    }

                    |   
                    {
                        $$.traducao = "";
                    }

    /* Tipos */
TIPO                : TK_TIPO_INT   { $$.tipo = "int";   }
			        | TK_TIPO_FLOAT { $$.tipo = "float"; }
			        | TK_TIPO_CHAR  { $$.tipo = "char";  }
			        | TK_TIPO_BOOL  { $$.tipo = "bool";  }
			        ;

    /* COMANDO */
CMD             : TIPO TK_ID ';' //Declaração
                {
                    declarar_variavel($2.label, $1.tipo);
                    $$.traducao = "";
                }

                | TK_ID '=' E ';' //Atribuição
                {
                    simbolo simb = buscar_simbolo($1.label);

                    if(simb.tipo != $3.tipo){
                        yyerror("Erro: Atribuição com tipos diferentes");
                    }

                    $$.traducao = $3.traducao + "\t" + simb.label + " = " + $3.label + ";\n";
                }

                | E ';'
                {
                    $$.traducao = $1.traducao;
                }

                | TK_IMPRIME '(' E ')' ';'
                {
                    string formato;
                    if($3.tipo == "int")
                        formato = "%d";
                    else if($3.tipo == "float")
                        formato = "%f";
                    else if($3.tipo == "char")
                        formato = "%c";
                    else if($3.tipo == "bool")
                        formato = "%d";
                    
                    $$.traducao = $3.traducao + "\t" + "printf(\"" + formato + "\\n\", " + $3.label + ");\n";
                }
                ;

    /* Expressão */

    /* Identificador */
E               : TK_ID
                {
                    simbolo simb = buscar_simbolo($1.label);
                    $$.label = simb.label;
                    $$.tipo = simb.tipo;
                    $$.traducao = "";
                }    
               
    /*    Literais    */
                | TK_INT
                {
			        $$.label = getempcode("int");
			        $$.tipo = "int";
			        $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";                    
                }
                
                | TK_FLOAT
                {
                    $$.label = getempcode("float");
                    $$.tipo = "float";
                    $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                }

                | TK_CHAR
                {
                    $$.label = getempcode("char");
                    $$.tipo = "char";
                    $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                }

                | TK_BOOL
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n"; 
                }
    /*    Operadores aritméticos   */

                | E '+' E
                {
                    string l1, l2, tipo_final;
                    string trad_base = aplicar_coercao($1, $3, l1, l2, tipo_final);
            
                    $$.tipo = tipo_final;
                    $$.label = getempcode(tipo_final);
                    $$.traducao = trad_base + "\t" + $$.label + " = " + l1 + " + " + l2 + ";\n";
                }

                | E '-' E
                {
                    string l1, l2, tipo_final;
                    string trad_base = aplicar_coercao($1, $3, l1, l2, tipo_final);
            
                    $$.tipo = tipo_final;
                    $$.label = getempcode(tipo_final);
                    $$.traducao = trad_base + "\t" + $$.label + " = " + l1 + " - " + l2 + ";\n";
                }

                | E '*' E
                {
                    string l1, l2, tipo_final;
                    string trad_base = aplicar_coercao($1, $3, l1, l2, tipo_final);
            
                    $$.tipo = tipo_final;
                    $$.label = getempcode(tipo_final);
                    $$.traducao = trad_base + "\t" + $$.label + " = " + l1 + " * " + l2 + ";\n";
                }

                | E '/' E
                {
                    string l1, l2, tipo_final;
                    string trad_base = aplicar_coercao($1, $3, l1, l2, tipo_final);
            
                    $$.tipo = tipo_final;
                    $$.label = getempcode(tipo_final);
                    $$.traducao = trad_base + "\t" + $$.label + " = " + l1 + " / " + l2 + ";\n";
                }

    /*    Parênteses    */
                | '(' E ')'
                {
                    $$.label = $2.label;
                    $$.tipo = $2.tipo;
                    $$.traducao = $2.traducao;
                }
                ;
    /*    Casting       */
                | '(' TIPO ')' E %prec CAST_PREC
                {
                    $$.tipo = $2.tipo;
                    $$.label = getempcode($2.tipo);
                    $$.traducao = $4.traducao + "\t" + $$.label + " = (" + $2.tipo + ") " + $4.label + ";\n";
                }

    /*    Operadores Relacionais    */

                | E '<' E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " < " + $3.label + ";\n";
                }

                | E TK_LE E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " <= " + $3.label + ";\n";
                }

                | E '>' E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " > " + $3.label + ";\n";
                }

                | E TK_GE E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " >= " + $3.label + ";\n";
                }

                | E TK_EQ E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " == " + $3.label + ";\n";
                }

                | E TK_DIF E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " != " + $3.label + ";\n";
                }
    /*    Operadores lógicos    */
                | E TK_AND E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " && " + $3.label + ";\n";
                }

                | E TK_OR E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " || " + $3.label + ";\n";
                }

                | '!' E
                {
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $2.traducao + "\t" + $$.label +
                        " = " + " ! " + $2.label + ";\n";
                }

%%


#include "lex.yy.c"


string getempcode(string tipo){
    var_temp_qnt++;
    tipos_temporarios.push_back(tipo);

    return "t" + to_string(var_temp_qnt);
}


void declarar_variavel(string nome, string tipo){
    if(tabela_simbolos.count(nome)){
        yyerror("Erro: Variável \"" + nome + "\" já declarada");
        exit(1);
    }
    else{
        string variavel_usuario_sistema = "u_" + nome; 
        //souluciona conflito com variável de usuário e sistema com nomes iguais
        simbolo simb;
        simb.tipo = tipo;
        simb.label = variavel_usuario_sistema;
        tabela_simbolos[nome] = simb;
    }

}


simbolo buscar_simbolo(string nome){
    if(tabela_simbolos.count(nome)){
        return tabela_simbolos[nome];
    } else{
        yyerror("Erro: Variável \"" + nome + "\" não declarada");
        exit(1);
    }
}


string gerar_declaracoes(){
    string texto = "";

    //variaveis de usuário em de sistema
    for(auto const& [id, simb] : tabela_simbolos) {
        texto += "\t" + simb.tipo + " " + simb.label + "; //user:" + id + "\n";
        if(simb.tipo == "int")
            texto += "\t" + simb.label + " = 0; //inicialização\n";
        else if(simb.tipo == "float")
            texto += "\t" + simb.label + " = 0.0; //inicialização\n";
        else if(simb.tipo == "bool")
            texto += "\t" + simb.label + " = false; //inicialização\n";
        else if(simb.tipo == "char")
            texto += "\t" + simb.label + " = ' '; //inicialização\n";
    }

    //variaveis de sistema 
    for(int i=1; i<=tipos_temporarios.size(); i++){
        texto += "\t" + tipos_temporarios[i-1] + " t" + std::to_string(i) + ";\n";
    }
    return texto;
}


string aplicar_coercao(atributos &e1, atributos &e2, string &label_out1, string &label_out2, string &tipo_res) {
    string trad = e1.traducao + e2.traducao;
    label_out1 = e1.label;
    label_out2 = e2.label;

    if (e1.tipo == e2.tipo) {
        tipo_res = e1.tipo;
    } else if (e1.tipo == "float" && e2.tipo == "int") {
        tipo_res = "float";
        label_out2 = getempcode("float");
        trad += "\t" + label_out2 + " = (float) " + e2.label + ";\n";
    } else if (e1.tipo == "int" && e2.tipo == "float") {
        tipo_res = "float";
        label_out1 = getempcode("float");
        trad += "\t" + label_out1 + " = (float) " + e1.label + ";\n";
    } else {
        yyerror("Erro: Operação entre tipos incompatíveis");
    }
    return trad;
}

void imprimir_codigo_gerado(){
    cout << codigo_gerado;

    ofstream arquivo("codigo_c--.c");

    if (arquivo.is_open()) {
        arquivo << codigo_gerado << endl;
        arquivo.close();
    } else {
        cout << "Erro ao abrir o arquivo!" << endl;
    }

}

int main(){
    var_temp_qnt = 0;
    codigo_gerado = "";

    printf("\n");   
    
    yyparse();

    imprimir_codigo_gerado();


	return 0;
}

int yyerror(string MSG){
    cout << MSG << endl;
    exit(0);
}



