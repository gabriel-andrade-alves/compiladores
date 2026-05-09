%{
#include <iostream>
#include <string>
#include <sstream>
#include <fstream>
#include <unordered_map>   
#include <map> 
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

string matriz_conversao_implicita[4][4] = {
    //          int       float      char      bool
    /*int*/   {"int",   "float",   "erro",      "erro"},
    /*float*/ {"float", "float",   "erro",  	"erro"},
    /*char*/  {"erro",   "erro",   "erro",      "erro"},
    /*bool*/  {"erro",   "erro",   "erro",      "erro"}
};

string matriz_atribuicao[4][4] = {
	//          int       float      char      bool
    /*int*/   {"int",     "int",   "erro",   "erro"},
    /*float*/ {"float", "float",   "erro",   "erro"},
    /*char*/  {"erro",   "erro",   "char",   "erro"},
    /*bool*/  {"erro",   "erro",   "erro",   "bool"}
};

map<string, int> tipo_para_id = {
    {"int",   0},
    {"float", 1},
    {"char",  2},
    {"bool",  3}
};



int yylex(void);
int yyerror(string);
string getempcode(string tipo);
string gerar_declaracoes();
void declarar_variavel(string nome, string tipo);
simbolo buscar_simbolo(string nome);

string get_tipo_result(string t1, string t2) { return matriz_conversao_implicita[tipo_para_id[t1]][tipo_para_id[t2]]; } 
string get_tipo_atribuicao(string t1, string t2) { return matriz_atribuicao[tipo_para_id[t1]][tipo_para_id[t2]]; } 

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


//Relacional
%token TK_REL
%token TK_EQ
%token TK_DIF

//Logicos
%token TK_AND TK_OR


// Precedência
%left TK_OR
%left TK_AND
%left TK_EQ TK_DIF
%left TK_REL
%left '+' '-'
%left '*' '/'
%right CAST_PREC
%right '!'


//comandos
%token TK_IMPRIME
%token TK_LER


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
                    simbolo s = buscar_simbolo($1.label);
                    
                    string tipo_resultante = get_tipo_atribuicao(s.tipo, $3.tipo);
                    string linha_conversao = "";

                    string label_expressao = $3.label;

                    if (s.tipo != $3.tipo) {
                        if (tipo_resultante == "erro") {
                            yyerror("Atribuicao invalida");
                            exit(1);
                        }
                        else {
                            label_expressao = getempcode(tipo_resultante);
                            linha_conversao = "\t" + label_expressao + " = (" + tipo_resultante + ") "  +
                                $3.label + ";\n";
                        }
                    }

                    $$.traducao = $3.traducao + linha_conversao +"\t" + s.label + " = " + label_expressao + ";\n";
                }

                | TIPO TK_ID '=' E ';'
                {
                    declarar_variavel($2.label, $1.tipo);
                    $$.traducao = "";

                    simbolo s = buscar_simbolo($2.label);
                    
                    string tipo_resultante = get_tipo_atribuicao(s.tipo, $4.tipo);
                    string linha_conversao = "";

                    string label_expressao = $4.label;

                    if (s.tipo != $4.tipo) {
                        if (tipo_resultante == "erro") {
                            yyerror("Atribuicao invalida");
                            exit(1);
                        }
                        else {
                            label_expressao = getempcode(tipo_resultante);
                            linha_conversao = "\t" + label_expressao + " = (" + tipo_resultante + ") "  +
                                $4.label + ";\n";
                        }
                    }

                    $$.traducao = $4.traducao + linha_conversao +"\t" + s.label + " = " + label_expressao + ";\n";
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

                | TK_LER '(' TK_ID ')' ';'
                {
                    simbolo s = buscar_simbolo($3.label);
                    string formato;

                    if(s.tipo == "int")
                        formato = "%d";
                    else if(s.tipo == "float")
                        formato = "%f";
                    else if(s.tipo == "char")
                        formato = " %c";
                    else if(s.tipo == "bool")
                        formato = "%d";

                    $$.traducao = $3.traducao + "\t" + "scanf(\"" + formato + "\"," + " &" + s.label + ");\n";     

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
                    string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);

                    if (tipo_resultante == "erro") {
                        yyerror("Operacao com soma invalida");
                        exit(1);
                    }

                    string linha_conversao = "";

                    string operando1 = $1.label;
                    string operando2 = $3.label;

                    linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);


                    $$.label = getempcode(tipo_resultante);
                    $$.tipo = tipo_resultante;
                    $$.traducao = $1.traducao + $3.traducao + linha_conversao + 
                        "\t" + $$.label + " = " + operando1 + " + " + operando2 + ";\n";
                }

                | E '-' E
                {
                    string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);

                    if (tipo_resultante == "erro") {
                        yyerror("Operacao com soma invalida");
                        exit(1);
                    }

                    string linha_conversao = "";

                    string operando1 = $1.label;
                    string operando2 = $3.label;

                    linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);


                    $$.label = getempcode(tipo_resultante);
                    $$.tipo = tipo_resultante;
                    $$.traducao = $1.traducao + $3.traducao + linha_conversao + 
                        "\t" + $$.label + " = " + operando1 + " - " + operando2 + ";\n";
                }

                | E '*' E
                {
                    string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);

                    if (tipo_resultante == "erro") {
                        yyerror("Operacao com soma invalida");
                        exit(1);
                    }

                    string linha_conversao = "";

                    string operando1 = $1.label;
                    string operando2 = $3.label;

                    linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);


                    $$.label = getempcode(tipo_resultante);
                    $$.tipo = tipo_resultante;
                    $$.traducao = $1.traducao + $3.traducao + linha_conversao + 
                        "\t" + $$.label + " = " + operando1 + " * " + operando2 + ";\n";
                }

                | E '/' E
                {
                    string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);

                    if (tipo_resultante == "erro") {
                        yyerror("Operacao com soma invalida");
                        exit(1);
                    }

                    string linha_conversao = "";

                    string operando1 = $1.label;
                    string operando2 = $3.label;

                    linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);


                    $$.label = getempcode(tipo_resultante);
                    $$.tipo = tipo_resultante;
                    $$.traducao = $1.traducao + $3.traducao + linha_conversao + 
                        "\t" + $$.label + " = " + operando1 + " / " + operando2 + ";\n";
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

    /*    Operadores Relacionais */   

                | E TK_REL E
			    {
                    if ($1.tipo == "bool" || $3.tipo == "bool") {
                        yyerror("Operacao invalida");
                        exit(1);
                    }

                    string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);

                    if (tipo_resultante == "erro") {
                        yyerror("Operacao invalida");
                        exit(1);
                    }

                    string linha_conversao = "";

                    string operando1 = $1.label;
                    string operando2 = $3.label;

                    linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);

                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + linha_conversao +
                    "\t" + $$.label + " = " + operando1 + $2.label + operando2 + ";\n";		
			    }
            

                | E TK_EQ E
                {
                    string linha_conversao = "";

                    string operando1 = $1.label;
                    string operando2 = $3.label;


                    if ($1.tipo != $3.tipo) {
                        string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);
                        if (tipo_resultante == "erro") {
                            yyerror("Operacao invalida");
                            exit(1);
                        }

                        //Conversão Implícita
                        string operando1 = $1.label;
                        string operando2 = $3.label;

                        linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);
                    }

                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + linha_conversao + 
                    "\t" + $$.label + " = " + operando1 + " == " + operando2 + ";\n";		
                }

                | E TK_DIF E
                {
                    string linha_conversao = "";

                    string operando1 = $1.label;
                    string operando2 = $3.label;


                    if ($1.tipo != $3.tipo) {
                        string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);
                        if (tipo_resultante == "erro") {
                            yyerror("Operacao invalida: nao e possivel comparar '" + $1.tipo + "' com '" + $3.tipo + "'.");
                            exit(1);
                        }

                        //Conversão Implícita
                        string operando1 = $1.label;
                        string operando2 = $3.label;

                        linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);
                    }

                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + linha_conversao + 
                    "\t" + $$.label + " = " + operando1 + " != " + operando2 + ";\n";		
                }
                
    /*    Operadores lógicos    */
                | E TK_AND E
                {
                    if($1.tipo != "bool" || $3.tipo != "bool"){
                        yyerror("Operação Invalida: logico so pode operador bool");
                        exit(1);
                    }
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " && " + $3.label + ";\n";
                }

                | E TK_OR E
                {
                    if($1.tipo != "bool" || $3.tipo != "bool"){
                        yyerror("Operação Invalida: logico so pode operador bool");
                        exit(1);
                    }
                    $$.label = getempcode("bool");
                    $$.tipo = "bool";
                    $$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
                        " = " + $1.label + " || " + $3.label + ";\n";
                }

                | '!' E
                {
                    if($2.tipo != "bool"){
                        yyerror("Operação Invalida: bool so pode com bool");
                        exit(1);
                    }
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
    }

    //variaveis de sistema 
    for(int i=1; i<=tipos_temporarios.size(); i++){
        texto += "\t" + tipos_temporarios[i-1] + " t" + std::to_string(i) + ";\n";
    }

    //inicialização
    for(auto const& [id, simb] : tabela_simbolos) {
        if(simb.tipo == "int")
            texto += "\t" + simb.label + " = 0; //inicialização\n";
        else if(simb.tipo == "float")
            texto += "\t" + simb.label + " = 0.0; //inicialização\n";
        else if(simb.tipo == "bool")
            texto += "\t" + simb.label + " = false; //inicialização\n";
        else if(simb.tipo == "char")
            texto += "\t" + simb.label + " = ' '; //inicialização\n";
    }
    return texto;
}


string aplicar_coercao(atributos &e1, atributos &e2, string &operando1, string &operando2, string &tipo_resultante) {
    string linha_conversao;
    operando1 = e1.label;
    operando2 = e2.label;

    // Conversão Implícita
    if (e1.tipo != tipo_resultante) {
        operando1 = getempcode(tipo_resultante); 
        linha_conversao = "\t" + operando1 + " = (" + tipo_resultante + ") "  + e1.label + ";\n";
    }
    if (e2.tipo != tipo_resultante) {
        operando2 = getempcode(tipo_resultante);
        linha_conversao = "\t" + operando2 + " = (" + tipo_resultante + ") "  + e2.label + ";\n";
    }

    return linha_conversao;
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



