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
    string escopo; 
};


// facilita impressão final das declarações
struct declaracao_aux {
    string tipo;
    string label;
    string id_original;
};


int var_temp_qnt;
int label_qnt;
string codigo_gerado;
vector<string> tipos_temporarios;

//pilha de mapas para escopo
vector<unordered_map<string, simbolo>> pilha_tabelas;


//pilha para labels para o break e continue
vector<string> pilha_break;
vector<string> pilha_continue;


// para organizar a saída do código c--
vector<declaracao_aux> todas_variaveis_globais;
vector<declaracao_aux> todas_variaveis_locais;

int contador_escopos = 0;

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
string get_new_label();

string gerar_declaracoes_globais();
string gerar_declaracoes_locais();

void declarar_variavel(string nome, string tipo);
simbolo buscar_simbolo(string nome);

void abrir_escopo();
void fechar_escopo();

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
%right UMINUS
%right CAST_PREC
%right '!'
%right TK_INC TK_DEC


%nonassoc IF_SEM_ELSE
%nonassoc TK_ELSE


//comandos
%token TK_IMPRIME
%token TK_LER


//condicionais
%token TK_IF
%token TK_ELSE


//Repetição
%token TK_WHILE
%token TK_DO
%token TK_FOR


//Controles de laço de repetição
%token TK_BREAK
%token TK_ALL
%token TK_CONTINUE


%start S


%%



S                   : CONFIG_GLOBAL PROGRAMA
                    ;

// inicialização do escopo global
CONFIG_GLOBAL       : { pilha_tabelas.push_back(unordered_map<string, simbolo>()); }
                    ;

PROGRAMA            : DECLARACOES_GLOBAIS FUNCAO_MAIN
                    ;

DECLARACOES_GLOBAIS : DECLARACOES_GLOBAIS DECLARACAO_GLOBAL
                    |
                    ;

DECLARACAO_GLOBAL   : TIPO TK_ID ';'
                    {
                        declarar_variavel($2.label, $1.tipo);
                    }
                    ;

FUNCAO_MAIN         : TK_ID '(' ')' BLOCO
                    {
                        if ($2.label != "main") {
                            yyerror("Erro: a função principal deve se chamar 'main'");
                            exit(1);
                        }
                        
                        codigo_gerado =   string( "#include <stdio.h>\n") 
                                        + "#define true 1\n"
                                        + "#define false 0\n"
                                        + "#define bool int\n\n"
                                        + gerar_declaracoes_globais() + "\n"
                                        + "int main() {\n"
                                        + gerar_declaracoes_locais() + "\n"
                                        + $4.traducao
                                        + "\n\treturn 0;\n}\n";
                    }
                    ;

BLOCO               : '{' { abrir_escopo(); } COMANDOS '}'
                    {
                        fechar_escopo();
                        $$.traducao = $3.traducao;
                    }
                    ;


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
CMD             :TIPO TK_ID ';' //Declaração
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

                | TIPO TK_ID { declarar_variavel($2.label, $1.tipo); } '=' E ';' //atribuição + declaração
                {

                    simbolo s = buscar_simbolo($2.label); 
                    
                    string tipo_resultante = get_tipo_atribuicao(s.tipo, $5.tipo);
                    string linha_conversao = "";
                    string label_expressao = $5.label;

                    if (s.tipo != $5.tipo) {
                        if (tipo_resultante == "erro") {
                            yyerror("Atribuicao invalida");
                            exit(1);
                        }
                        else {
                            label_expressao = getempcode(tipo_resultante);
                            linha_conversao = "\t" + label_expressao + " = (" + tipo_resultante + ") "  + $5.label + ";\n";
                        }
                    }

                    $$.traducao = $5.traducao + linha_conversao + "\t" + s.label + " = " + label_expressao + ";\n";
                }

                | E ';' //Somente expressão
                {
                    $$.traducao = $1.traducao;
                }


    /*  Comandos de impressão e leitura  */
                | TK_IMPRIME '(' ARGUMENTOS ')' ';' 
                {
                    // Encontra a posição do caractere especial '|' enviado por ARGUMENTOS
                    size_t pos = $3.label.find('|');
                    
                    // Separa o que está antes (formatos) do que está depois (variáveis)
                    string formatos = $3.label.substr(0, pos);
                    string variaveis = $3.label.substr(pos + 1);

                    string newLine;

                    if($1.label == "imp")
                        newLine = "";
                    else 
                        newLine = "\\n";

                    $$.traducao = $3.traducao 
                                  + string("\t") + "printf(\"" + formatos + newLine + "\"";
                    if(variaveis != ""){
                        $$.traducao += ", " + variaveis;
                    }

                    $$.traducao += ");\n";
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
    /*  Bloco  */
                | BLOCO
                {
                    $$.traducao = "\t{\n" + $1.traducao + "\t}\n";
                }

    /* Comandos condicionais */
                | TK_IF '(' E ')' CORPO_CONDICIONAL %prec IF_SEM_ELSE
                {
                    if ($3.tipo != "bool") {
                        yyerror("Erro semântico: A condição do 'if' deve ser do tipo bool.");
                        exit(1);
                    }

                    string label_fim = get_new_label();

                    $$.traducao = $3.traducao 
                                  + "\tif (!" + $3.label + ") goto " + label_fim + ";\n"
                                  + $5.traducao 
                                  + "\t" + label_fim + ":\n";
                }

                | TK_IF '(' E ')' CORPO_CONDICIONAL TK_ELSE CORPO_CONDICIONAL
                {
                    if ($3.tipo != "bool") {
                        yyerror("Erro semântico: A condição do 'if' deve ser do tipo bool.");
                        exit(1);
                    }

                    string label_else = get_new_label();
                    string label_fim = get_new_label();

                    $$.traducao = $3.traducao 
                                  + "\tif (!" + $3.label + ") goto " + label_else + ";\n"
                                  + $5.traducao 
                                  + "\tgoto " + label_fim + ";\n"
                                  + "\t" + label_else + ":\n"
                                  + $7.traducao 
                                  + "\t" + label_fim + ":\n";
                }
                
    /* While */
                | TK_WHILE '(' E ')'
                {
                    string lf = get_new_label();
                    string li = get_new_label();
                    pilha_break.push_back(lf);
                    pilha_continue.push_back(li);   
                }
                CORPO_CONDICIONAL
                {
                    if ($3.tipo != "bool") {
                        yyerror("Erro semântico: A condição do 'while' deve ser do tipo bool.");
                        exit(1);
                    }

                    string label_fim    = pilha_break.back();    pilha_break.pop_back();
                    string label_inicio = pilha_continue.back(); pilha_continue.pop_back();

                    $$.traducao = "\t" + label_inicio + ":\n"
                                + $3.traducao
                                + "\tif (!" + $3.label + ") goto " + label_fim + ";\n"
                                + $6.traducao
                                + "\tgoto " + label_inicio + ";\n"
                                + "\t" + label_fim + ":\n";
                }
                

    /* do while */
                | TK_DO
                {
                    string lf = get_new_label();
                    string li = get_new_label();
                    pilha_break.push_back(lf);
                    pilha_continue.push_back(li);   
                }
                CORPO_CONDICIONAL TK_WHILE '(' E ')'
                {
                    if ($6.tipo != "bool") {
                        yyerror("Erro semântico: A condição do 'while' deve ser do tipo bool.");
                        exit(1);
                    }

                    string label_fim    = pilha_break.back();    pilha_break.pop_back();
                    string label_inicio = pilha_continue.back(); pilha_continue.pop_back();

                    $$.traducao = "\t" + label_inicio + ":\n"
                                + $3.traducao
                                + $6.traducao
                                + "\tif (" + $6.label + ") goto " + label_inicio + ";\n"
                                + "\t" + label_fim + ":\n";
                }

    /* for */
                | TK_FOR '(' { abrir_escopo(); } FOR_INIT ';' E ';' FOR_INC ')'
                {
                    string lf  = get_new_label();
                    string linc = get_new_label(); // label para incremento
                    pilha_break.push_back(lf);
                    pilha_continue.push_back(linc); // continue → incremento
                }
                CORPO_CONDICIONAL { fechar_escopo(); }
                {
                    if ($6.tipo != "bool") {
                        yyerror("Erro semantico: A condicao do 'for' deve ser do tipo bool.");
                        exit(1);
                    }

                    string label_fim = pilha_break.back();    pilha_break.pop_back();
                    string label_inc = pilha_continue.back(); pilha_continue.pop_back();
                    string label_ini = get_new_label();

                    $$.traducao = $4.traducao                                              // init
                                + "\t" + label_ini + ":\n"                                // L_ini:
                                + $6.traducao                                              // cond
                                + "\tif (!" + $6.label + ") goto " + label_fim + ";\n"   // if (!cond) goto L_fim
                                + $11.traducao                                             // corpo
                                + "\t" + label_inc + ":\n"                                // L_inc:  ← continue vem aqui
                                + $8.traducao                                              // incremento
                                + "\tgoto " + label_ini + ";\n"                           // goto L_ini
                                + "\t" + label_fim + ":\n";                               // L_fim:
                }
    
        /* break */
                | TK_BREAK ';'
                {
                    if (pilha_break.empty()) {
                        yyerror("Erro: 'break' fora de um loop.");
                        exit(1);
                    }
                    $$.traducao = "\tgoto " + pilha_break.back() + ";\n";
                }

        /* break n*/
                | TK_BREAK TK_INT ';'
                {
                    if (pilha_break.empty()) {
                        yyerror("Erro: 'break' fora de um loop.");
                        exit(1);
                    }

                    int n = stoi($2.label);

                    if (n <= 0) {
                        yyerror("Erro: 'break' deve receber um numero positivo.");
                        exit(1);
                    }
                    if ((int)pilha_break.size() < n) {
                        yyerror("Erro: 'break " + $2.label + "' excede o numero de loops ativos (" 
                                + to_string(pilha_break.size()) + ").");
                        exit(1);
                    }

                    string label_alvo = pilha_break[pilha_break.size() - n];

                    $$.traducao = "\tgoto " + label_alvo + ";\n";
                }

        /* break all*/
                | TK_BREAK TK_ALL ';'
                {
                    if (pilha_break.empty()) {
                        yyerror("Erro: 'break all' fora de um loop.");
                        exit(1);
                    }
                    $$.traducao = "\tgoto " + pilha_break.front() + ";\n";
                }


                | TK_CONTINUE ';'
                {
                    if (pilha_continue.empty()) {
                        yyerror("Erro: 'continue' fora de um loop.");
                        exit(1);
                    }
                    $$.traducao = "\tgoto " + pilha_continue.back() + ";\n";
                }

                | TK_CONTINUE TK_INT ';'
                {
                    if (pilha_continue.empty()) {
                        yyerror("Erro: 'continue' fora de um loop.");
                        exit(1);
                    }

                    int n = stoi($2.label);

                    if (n <= 0) {
                        yyerror("Erro: 'continue' deve receber um numero positivo.");
                        exit(1);
                    }
                    if ((int)pilha_continue.size() < n) {
                        yyerror("Erro: 'continue " + $2.label + "' excede o numero de loops ativos ("
                                + to_string(pilha_continue.size()) + ").");
                        exit(1);
                    }

                    string label_alvo = pilha_continue[pilha_continue.size() - n];
                    $$.traducao = "\tgoto " + label_alvo + ";\n";
                }
                ;


    /* regras para o for */
                FOR_INIT : TIPO TK_ID { declarar_variavel($2.label, $1.tipo); } '=' E
                        {
                            simbolo s = buscar_simbolo($2.label);
                            string tipo_resultante = get_tipo_atribuicao(s.tipo, $5.tipo);
                            string linha_conversao = "";
                            string label_expressao = $5.label;

                            if (s.tipo != $5.tipo) {
                                if (tipo_resultante == "erro") {
                                    yyerror("Atribuicao invalida no for");
                                    exit(1);
                                }
                                label_expressao = getempcode(tipo_resultante);
                                linha_conversao = "\t" + label_expressao + " = (" + tipo_resultante + ") " + $5.label + ";\n";
                            }

                            $$.traducao = $5.traducao + linha_conversao + "\t" + s.label + " = " + label_expressao + ";\n";
                        }

                    | TK_ID '=' E
                    {
                        simbolo s = buscar_simbolo($1.label);
                        string tipo_resultante = get_tipo_atribuicao(s.tipo, $3.tipo);
                        string linha_conversao = "";
                        string label_expressao = $3.label;

                        if (s.tipo != $3.tipo) {
                            if (tipo_resultante == "erro") {
                                yyerror("Atribuicao invalida no for");
                                exit(1);
                            }
                            label_expressao = getempcode(tipo_resultante);
                            linha_conversao = "\t" + label_expressao + " = (" + tipo_resultante + ") " + $3.label + ";\n";
                        }

                        $$.traducao = $3.traducao + linha_conversao + "\t" + s.label + " = " + label_expressao + ";\n";
                    }

                    |
                    {
                        $$.traducao = "";
                    }



                FOR_INC  : TK_ID TK_INC
                        {
                            simbolo s = buscar_simbolo($1.label);
                            if (s.tipo != "int" && s.tipo != "float") {
                                yyerror("Operador ++ so pode ser usado com int ou float");
                                exit(1);
                            }
                            string soma;
                            if(s.tipo == "int")
                                soma = " + 1";
                            else
                                soma = " + 1.0";

                            $$.traducao = "\t" + s.label + " = " + s.label + soma + ";\n";
                        }
                        | TK_ID TK_DEC
                        {
                            simbolo s = buscar_simbolo($1.label);
                            if (s.tipo != "int" && s.tipo != "float") {
                                yyerror("Operador -- so pode ser usado com int ou float");
                                exit(1);
                            }

                            string soma;
                            if(s.tipo == "int")
                                soma = " - 1";
                            else
                                soma = " - 1.0";

                            $$.traducao = "\t" + s.label + " = " + s.label + soma + ";\n";
                        }
                        | TK_ID '=' E
                        {
                            simbolo s = buscar_simbolo($1.label);
                            $$.traducao = $3.traducao + "\t" + s.label + " = " + $3.label + ";\n";
                        }
                        |   // incremento vazio: for(init ; cond ; )
                        {
                            $$.traducao = "";
                        }
                        ;




CORPO_CONDICIONAL   : CMD
                {
                            $$.traducao = $1.traducao;
                }
                ;

ARGUMENTOS  :   ARGUMENTOS ',' ARG
                {
                    size_t posA = $1.label.find('|');
                    size_t posR = $3.label.find('|');

                    string fA = $1.label.substr(0, posA);
                    string vA = $1.label.substr(posA + 1);

                    string fR = $3.label.substr(0, posR);
                    string vR = $3.label.substr(posR + 1);

                    $$.traducao = $1.traducao + $3.traducao;
                    $$.label = fA + ", " + fR + "|" + vA + ", " + vR;
                }
                |   ARG
                    {
                        $$.traducao = $1.traducao;
                        $$.label = $1.label;
                    }
                |
            ;

ARG         :   E
                {
                    string formato;
                    if($1.tipo == "int")       formato = "%d";
                    else if($1.tipo == "float") formato = "%f";
                    else if($1.tipo == "char")  formato = "%c";
                    else if($1.tipo == "bool")  formato = "%d";
                    
                    $$.traducao = $1.traducao; // Código intermediário gerado em E (ex: t1=2; t2=t1/b...)
                    $$.label = formato + "|" + $1.label; // "ex: %d|t3"
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

    /*  Operadores unários    */
                | '-' E %prec UMINUS
                {
                    if($2.tipo != "int" ||$2.tipo != "float" ){
                        yyerror("Menos unário somente com int ou float");
                        exit(1);
                    }
                    $$.label = getempcode($2.tipo);
                    $$.tipo = $2.tipo;
                    $$.traducao = $2.traducao + "\t" + $$.label + " = -" + $2.label + ";\n";
                }
                /* ++ e -- pós-fixado*/
                | TK_ID TK_INC
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (s.tipo != "int" && s.tipo != "float") {
                        yyerror("Operador ++ so pode ser usado com int ou float");
                        exit(1);
                    }
                    string temp = getempcode(s.tipo);
                    $$.label    = temp;
                    $$.tipo     = s.tipo;

                    string soma;
                    if(s.tipo == "int")
                        soma = " + 1";
                    else
                        soma = " + 1.0";

                    // 1º salva o valor antigo em temp, 2º incrementa a variável
                    $$.traducao = "\t" + temp + " = " + s.label + ";\n"
                                + "\t" + s.label + " = " + s.label + soma + ";\n";
                }
                | TK_ID TK_DEC
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (s.tipo != "int" && s.tipo != "float") {
                        yyerror("Operador -- so pode ser usado com int ou float");
                        exit(1);
                    }
                    string temp = getempcode(s.tipo);
                    $$.label = temp;
                    $$.tipo  = s.tipo;

                    string soma;
                    if(s.tipo == "int")
                        soma = " - 1";
                    else
                        soma = " - 1.0";

                    $$.traducao = "\t" + temp + " = " + s.label + ";\n"
                                + "\t" + s.label + " = " + s.label + soma + ";\n";
                }
                /* ++ e -- pré-fixado*/
                | TK_INC TK_ID
                {
                    simbolo s = buscar_simbolo($2.label);
                    if (s.tipo != "int" && s.tipo != "float") {
                        yyerror("Operador ++ so pode ser usado com int ou float");
                        exit(1);
                    }
                    // Incrementa e retorna o novo valor (o próprio s.label)
                    $$.label = s.label;
                    $$.tipo  = s.tipo;

                    string soma;
                    if(s.tipo == "int")
                        soma = " + 1";
                    else
                        soma = " + 1.0";

                    $$.traducao = "\t" + s.label + " = " + s.label + soma + ";\n";
                }

                | TK_DEC TK_ID
                {
                    simbolo s = buscar_simbolo($2.label);
                    if (s.tipo != "int" && s.tipo != "float") {
                        yyerror("Operador -- so pode ser usado com int ou float");
                        exit(1);
                    }
                    $$.label = s.label;
                    $$.tipo  = s.tipo;

                    string soma;
                    if(s.tipo == "int")
                        soma = " - 1";
                    else
                        soma = " - 1.0";

                    $$.traducao = "\t" + s.label + " = " + s.label + soma + ";\n";
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

string get_new_label() {
    label_qnt++;
    return "L" + to_string(label_qnt);
}

void abrir_escopo() {
    contador_escopos++;
    pilha_tabelas.push_back(unordered_map<string, simbolo>());
}


void fechar_escopo() {
    if (pilha_tabelas.size() > 1) {
        pilha_tabelas.pop_back();
    } else {
        yyerror("Erro: IMPOSSÍVEL fechar escopo global.");
        exit(1);
    }
}

void declarar_variavel(string nome, string tipo){
    // Checa duplicidade apenas no escopo atual
    if(pilha_tabelas.back().count(nome)){
        yyerror("Erro: Variável \"" + nome + "\" já declarada neste escopo");
        exit(1);
    }
    
    simbolo simb;
    simb.tipo = tipo;
    
    // Se só tem 1 elemento = escopo global
    if (pilha_tabelas.size() == 1) {
        simb.label = "g_" + nome; // prefixo 'g_' para globais
        simb.escopo = "global";
        pilha_tabelas.back()[nome] = simb;
        
        declaracao_aux decl = {tipo, simb.label, nome};
        todas_variaveis_globais.push_back(decl);
    } 
    else {
        // Escopos locais ganham sufixo para evitar colisão
        simb.label = "u_" + nome + "_escopo" + to_string(contador_escopos);
        simb.escopo = "local";
        pilha_tabelas.back()[nome] = simb;
        
        declaracao_aux decl = {tipo, simb.label, nome};
        todas_variaveis_locais.push_back(decl);
    }
}


simbolo buscar_simbolo(string nome){
    // Varredura Top-Down (do escopo mais interno até o global no índice 0)
    for (int i = pilha_tabelas.size() - 1; i >= 0; i--) {
        if (pilha_tabelas[i].count(nome)) {
            return pilha_tabelas[i][nome];
        }
    }
    yyerror("Erro: Variável \"" + nome + "\" não declarada");
    exit(1);
}


string gerar_declaracoes_globais(){
    string texto = "";
    for(auto const& decl : todas_variaveis_globais) {
        string inicializacao = " = 0;";
        if(decl.tipo == "float") inicializacao = " = 0.0;";
        else if(decl.tipo == "bool") inicializacao = " = false;";
        else if(decl.tipo == "char") inicializacao = " = ' ';";
        
        texto += decl.tipo + " " + decl.label + inicializacao + " // global user:" + decl.id_original + "\n";
    }
    return texto;
}

string gerar_declaracoes_locais(){
    string texto = "";
    
    for(auto const& decl : todas_variaveis_locais) {
        texto += "\t" + decl.tipo + " " + decl.label + "; // local user:" + decl.id_original + "\n";
    }

    texto += "";
    for(int i = 1; i <= tipos_temporarios.size(); i++){
        texto += "\t" + tipos_temporarios[i-1] + " t" + to_string(i) + ";\n";
    }

    texto += "";
    for(auto const& decl : todas_variaveis_locais) {
        if(decl.tipo == "int")
            texto += "\t" + decl.label + " = 0;\n";
        else if(decl.tipo == "float")
            texto += "\t" + decl.label + " = 0.0;\n";
        else if(decl.tipo == "bool")
            texto += "\t" + decl.label + " = false;\n";
        else if(decl.tipo == "char")
            texto += "\t" + decl.label + " = ' ';\n";
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



