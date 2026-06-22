%{
#include <iostream>
#include <string>
#include <sstream>
#include <fstream>
#include <unordered_map>   
#include <map> 
#include <vector>
#include <cstring>

using namespace std;
#define YYSTYPE atributos

struct atributos
{
	string label;
	string traducao;
    string tipo;
    int tamanho; // usado por string: tamanho
    vector<string> lista_tipos;   // tipos dos argumentos de uma chamada
    vector<string> lista_labels;  // labels (já traduzidos) dos argumentos
};

struct simbolo
{
    string label;
    string tipo;
    string escopo;
    bool referencia = false;
    bool is_array = false; // identificador para vetores/matrizes
    int dim1 = 0;          // Tamanho da 1ª dimensão
    int dim2 = 0;          // Tamanho da 2ª dimensão
};

// facilita impressão final das declarações
struct declaracao_aux {
    string tipo;
    string label;
    string id_original;
    bool is_array = false; 
    int tamanho_total = 0; // Tamanho linear total (dim1 * dim2)
};

struct funcao_info {
    string tipo_retorno;        // "int","float","char","bool","string","void"
    vector<string> tipos_param; // tipos dos parâmetros, na ordem
    string label;               // nome traduzido, ex: "f_soma"
};

unordered_map<string, funcao_info> tabela_funcoes;

// dados da função sendo compilada no momento (não há funções aninhadas,
// então não precisa ser uma pilha)
string tipo_retorno_atual;

// parâmetros coletados durante o parsing do cabeçalho da função atual
vector<declaracao_aux> parametros_atual;

// protótipos (forward declarations) e corpos das funções já compiladas
vector<string> prototipos_funcoes;
string codigo_funcoes;


int var_temp_qnt;
int label_qnt;
string codigo_gerado;
vector<string> tipos_temporarios;

//pilha de mapas para escopo
vector<unordered_map<string, simbolo>> pilha_tabelas;


//pilha para labels para o break e continue
vector<string> pilha_break;
vector<string> pilha_continue;

// pilhas para o switch: temporário da expressão e label de fim
vector<string> pilha_sw_temp;
vector<string> pilha_sw_fim;


// para organizar a saída do código c--
vector<declaracao_aux> todas_variaveis_globais;
vector<declaracao_aux> todas_variaveis_locais;

int contador_escopos = 0;

string matriz_conversao_implicita[6][6] = {
    //             int       float      char        bool      string     void
    /*int*/    {"int",    "float",   "erro",     "erro",   "erro",   "erro"},
    /*float*/  {"float",  "float",   "erro",     "erro",   "erro",   "erro"},
    /*char*/   {"erro",   "erro",    "string",   "erro",   "string", "erro"},
    /*bool*/   {"erro",   "erro",    "erro",     "erro",   "erro",   "erro"},
    /*string*/ {"erro",   "erro",    "string",   "erro",   "string", "erro"},
    /*void*/   {"erro",   "erro",    "erro",     "erro",   "erro",   "erro"}
};

string matriz_atribuicao[6][6] = {
    //             int       float      char      bool     string    void
    /*int*/    {"int",    "int",     "erro",   "erro",   "erro",  "erro"},
    /*float*/  {"float",  "float",   "erro",   "erro",   "erro",  "erro"},
    /*char*/   {"erro",   "erro",    "char",   "erro",   "erro",  "erro"},
    /*bool*/   {"erro",   "erro",    "erro",   "bool",   "erro",  "erro"},
    /*string*/ {"erro",   "erro",    "erro",   "erro",   "string","erro"},
    /*void*/   {"erro",   "erro",    "erro",   "erro",   "erro",  "erro"}
};

map<string, int> tipo_para_id = {
    {"int",    0},
    {"float",  1},
    {"char",   2},
    {"bool",   3},
    {"string", 4},
    {"void",   5}
};



int yylex(void);
int yyerror(string);
string getempcode(string tipo);
string get_new_label();

string gerar_declaracoes_globais();
string gerar_declaracoes_locais();
void declarar_array(string nome, string tipo, int dim1, int dim2 = 0);
string gerar_preambulo();

void declarar_variavel(string nome, string tipo);
void declarar_parametro(string nome, string tipo, bool is_array);
simbolo buscar_simbolo(string nome);
string acessar_simbolo(const simbolo& s);

void abrir_escopo();
void fechar_escopo();

string get_tipo_result(string t1, string t2) {
    return matriz_conversao_implicita[tipo_para_id[t1]][tipo_para_id[t2]];
}
string get_tipo_atribuicao(string t1, string t2) {
    return matriz_atribuicao[tipo_para_id[t1]][tipo_para_id[t2]];
}

string aplicar_coercao(atributos &e1, atributos &e2, string &label_out1, string &label_out2, string &tipo_res);
%}


//Literais
%token TK_INT
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOL
%token TK_STRING


//Tipos
%token TK_TIPO_INT
%token TK_TIPO_FLOAT
%token TK_TIPO_CHAR
%token TK_TIPO_BOOL
%token TK_TIPO_STRING
%token TK_TIPO_VOID


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
%token TK_RETURN


//condicionais
%token TK_IF
%token TK_ELSE

//switch
%token TK_SWITCH
%token TK_CASE
%token TK_DEFAULT
%token TK_PONTOS


//Repetição
%token TK_WHILE
%token TK_DO
%token TK_FOR


//Controles de laço de repetição
%token TK_BREAK
%token TK_ALL
%token TK_CONTINUE

// Operadores compostos
%token TK_MAIS_IGUAL
%token TK_MENOS_IGUAL
%token TK_VEZES_IGUAL
%token TK_DIV_IGUAL

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
                    | DECLARACOES_GLOBAIS FUNCAO
                    |
                    ;

FUNCAO              : TIPO TK_ID '('
                    {
                        abrir_escopo();           // escopo dos parâmetros
                        parametros_atual.clear();
                    }
                    PARAMETROS ')'
                    {
                        if ($2.label == "main") {
                            yyerror("Erro: 'main' e reservado para o ponto de entrada.");
                            exit(1);
                        }
                        if (tabela_funcoes.count($2.label)) {
                            yyerror("Erro: funcao \"" + $2.label + "\" ja declarada.");
                            exit(1);
                        }

                        funcao_info finfo;
                        finfo.tipo_retorno = $1.tipo;
                        finfo.label = "f_" + $2.label;
                        for (auto const& p : parametros_atual)
                            finfo.tipos_param.push_back(p.tipo);

                        tabela_funcoes[$2.label] = finfo;

                        tipo_retorno_atual = $1.tipo;

                        // buffers de locais/temporários ficam isolados por função
                        todas_variaveis_locais.clear();
                        tipos_temporarios.clear();
                        var_temp_qnt = 0;
                    }
                    BLOCO
                    {
                        fechar_escopo();           // fecha escopo dos parâmetros

                        funcao_info& finfo = tabela_funcoes[$2.label];

                        string assinatura = (finfo.tipo_retorno == "void" ? "void" : finfo.tipo_retorno)
                                           + " " + finfo.label + "(";
                        for (size_t i = 0; i < parametros_atual.size(); i++) {
                            if (i > 0) assinatura += ", ";
                            
                            string tparam = parametros_atual[i].tipo;
                            if (tparam == "string") {
                                tparam = "char**";
                            } else if (parametros_atual[i].is_array) {
                                tparam += "*"; // Se for array, o tipo em C será 'int*', 'float*', etc.
                            }
                            
                            assinatura += tparam + " " + parametros_atual[i].label;
                        }
                        assinatura += ")";

                        prototipos_funcoes.push_back(assinatura + ";\n");

                        codigo_funcoes += assinatura + " {\n"
                                        + gerar_declaracoes_locais()
                                        + "\n"
                                        + $8.traducao
                                        + "}\n\n";
                    }
                    ;

PARAMETROS          : PARAMETROS ',' PARAMETRO
                    | PARAMETRO
                    |
                    ;

PARAMETRO           : TIPO TK_ID
                    {
                        declarar_parametro($2.label, $1.tipo, false);
                    }
                    // Recebendo um Vetor
                    | TIPO TK_ID '[' ']'
                    {
                        declarar_parametro($2.label, $1.tipo, true);
                    }
                    // Recebendo uma Matriz
                    | TIPO TK_ID '[' ']' '[' ']'
                    {
                        declarar_parametro($2.label, $1.tipo, true);
                    }
                    ;

DECLARACAO_GLOBAL   : TIPO TK_ID ';'
                    {
                        declarar_variavel($2.label, $1.tipo);
                    }
                    | TIPO TK_ID '[' TK_INT ']' ';'
                    {
                        declarar_array($2.label, $1.tipo, stoi($4.label));
                    }
                    | TIPO TK_ID '[' TK_INT ']' '[' TK_INT ']' ';'
                    {
                        declarar_array($2.label, $1.tipo, stoi($4.label), stoi($7.label));
                    }
                    ;

FUNCAO_MAIN         : TK_ID '(' ')'
                    {
                        if ($1.label != "main") {
                            yyerror("Erro: a funcao principal deve se chamar 'main'");
                            exit(1);
                        }

                        tipo_retorno_atual = "int"; // main se comporta como int

                        todas_variaveis_locais.clear();
                        tipos_temporarios.clear();
                        var_temp_qnt = 0;
                    }
                    BLOCO
                    {
                        string protos = "";
                        for (auto const& p : prototipos_funcoes) protos += p;

                        codigo_gerado = gerar_preambulo()
                                        + gerar_declaracoes_globais() + "\n"
                                        + protos + "\n"
                                        + codigo_funcoes
                                        + "int main() {\n"
                                        + gerar_declaracoes_locais() + "\n"
                                        + $5.traducao
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
TIPO                : TK_TIPO_INT    { $$.tipo = "int";    }
			        | TK_TIPO_FLOAT  { $$.tipo = "float";  }
			        | TK_TIPO_CHAR   { $$.tipo = "char";   }
			        | TK_TIPO_BOOL   { $$.tipo = "bool";   }
			        | TK_TIPO_STRING { $$.tipo = "string"; }
                    | TK_TIPO_VOID   { $$.tipo = "void";   }
			        ;


OP_COMP             : TK_MAIS_IGUAL   { $$.label = "+="; }
                    | TK_MENOS_IGUAL  { $$.label = "-="; }
                    | TK_VEZES_IGUAL  { $$.label = "*="; }
                    | TK_DIV_IGUAL    { $$.label = "/="; }
                    ;

    /* COMANDO */
CMD             :TIPO TK_ID ';' //Declaração
                {
                    declarar_variavel($2.label, $1.tipo);
                    $$.traducao = "";
                }
                
                //vetores e matrizes
                | TIPO TK_ID '[' TK_INT ']' ';' 
                {
                    declarar_array($2.label, $1.tipo, stoi($4.label));
                    $$.traducao = "";
                }
                
                | TIPO TK_ID '[' TK_INT ']' '[' TK_INT ']' ';' 
                {
                    declarar_array($2.label, $1.tipo, stoi($4.label), stoi($7.label));
                    $$.traducao = "";
                }

                | TK_ID '=' E ';'
                {
                    simbolo s = buscar_simbolo($1.label);
                    string alvo = acessar_simbolo(s);

                    string tipo_resultante = get_tipo_atribuicao(s.tipo, $3.tipo);
                    if (tipo_resultante == "erro") {
                        yyerror("Atribuicao invalida");
                        exit(1);
                    }

                    if (tipo_resultante == "string") {
                        string tsz = getempcode("int");
                        $$.traducao = $3.traducao
                                    + "\t" + tsz + " = __str_len(" + $3.label + ");\n"
                                    + "\t" + "free(" + alvo + ");\n"
                                    + "\t" + alvo + " = (char*) malloc(" + tsz + ");\n"
                                    + "\tstrcpy(" + alvo + ", " + $3.label + ");\n";
                    } else {
                        string linha_conversao = "";
                        string label_expressao = $3.label;
                        if (s.tipo != $3.tipo) {
                            label_expressao = getempcode(tipo_resultante);
                            linha_conversao = "\t" + label_expressao + " = (" + tipo_resultante + ") " + $3.label + ";\n";
                        }
                        $$.traducao = $3.traducao + linha_conversao + "\t" + alvo + " = " + label_expressao + ";\n";
                    }
                }
                
                | TK_ID '[' E ']' '=' E ';'
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (!s.is_array || s.dim2 != 0) { yyerror("Erro: uso incorreto de vetor."); exit(1); }
                    if ($3.tipo != "int") { yyerror("Erro: indice do vetor deve ser inteiro."); exit(1); }
                    
                    string tipo_res = get_tipo_atribuicao(s.tipo, $6.tipo);
                    if (tipo_res == "erro") { yyerror("Atribuicao invalida no vetor."); exit(1); }
                    
                    string operando2 = $6.label;
                    string linha_conversao = "";
                    if (s.tipo != $6.tipo) {
                        operando2 = getempcode(tipo_res);
                        linha_conversao = "\t" + operando2 + " = (" + tipo_res + ") " + $6.label + ";\n";
                    }
                    
                    $$.traducao = $3.traducao + $6.traducao + linha_conversao + 
                                "\t" + acessar_simbolo(s) + "[" + $3.label + "] = " + operando2 + ";\n";
                }

                | TK_ID '[' E ']' '[' E ']' '=' E ';'
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (!s.is_array || s.dim2 == 0) { yyerror("Erro: uso incorreto de matriz."); exit(1); }
                    if ($3.tipo != "int" || $6.tipo != "int") { yyerror("Erro: indices da matriz devem ser inteiros."); exit(1); }
                    
                    string tipo_res = get_tipo_atribuicao(s.tipo, $9.tipo);
                    if (tipo_res == "erro") { yyerror("Atribuicao invalida na matriz."); exit(1); }
                    
                    string t_mult = getempcode("int");
                    string t_soma = getempcode("int");
                    string calc_offset = "\t" + t_mult + " = " + $3.label + " * " + to_string(s.dim2) + ";\n"
                                    + "\t" + t_soma + " = " + t_mult + " + " + $6.label + ";\n";
                    
                    string operando_val = $9.label;
                    string linha_conversao = "";
                    if (s.tipo != $9.tipo) {
                        operando_val = getempcode(tipo_res);
                        linha_conversao = "\t" + operando_val + " = (" + tipo_res + ") " + $9.label + ";\n";
                    }
                    
                    $$.traducao = $3.traducao + $6.traducao + $9.traducao + calc_offset + linha_conversao + 
                                "\t" + acessar_simbolo(s) + "[" + t_soma + "] = " + operando_val + ";\n";
                }

                | TK_ID OP_COMP E ';'
                {
                    simbolo s = buscar_simbolo($1.label);
                    string alvo = acessar_simbolo(s);

                    if (s.tipo != "int" && s.tipo != "float") {
                        yyerror("Operadores compostos so podem ser usados com int ou float.");
                        exit(1);
                    }

                    string tipo_res = get_tipo_result(s.tipo, $3.tipo);
                    if (tipo_res == "erro") {
                        yyerror("Atribuicao composta invalida.");
                        exit(1);
                    }

                    string operando2 = $3.label;
                    string linha_conversao = "";
                    if (s.tipo != $3.tipo) {
                        operando2 = getempcode(tipo_res);
                        linha_conversao = "\t" + operando2 + " = (" + tipo_res + ") " + $3.label + ";\n";
                    }

                    // Gera a operacao base (ex: t1 = alvo + op2)
                    string t_op = getempcode(tipo_res);
                    string op_aritmetica = "\t" + t_op + " = " + alvo + " " + $2.label.at(0) + " " + operando2 + ";\n";

                    // Atribui o temporário de volta ao alvo (ex: alvo = t1)
                    $$.traducao = $3.traducao + linha_conversao + op_aritmetica + "\t" + alvo + " = " + t_op + ";\n";
                }

                | TK_ID '[' E ']' OP_COMP E ';'
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (!s.is_array || s.dim2 != 0) { yyerror("Erro: uso incorreto de vetor."); exit(1); }
                    if ($3.tipo != "int") { yyerror("Erro: indice do vetor deve ser inteiro."); exit(1); }
                    
                    if (s.tipo != "int" && s.tipo != "float") {
                        yyerror("Operadores compostos so podem ser usados com int ou float.");
                        exit(1);
                    }

                    string tipo_res = get_tipo_result(s.tipo, $6.tipo);
                    if (tipo_res == "erro") { yyerror("Atribuicao composta invalida no vetor."); exit(1); }

                    string operando2 = $6.label;
                    string linha_conversao = "";
                    if (s.tipo != $6.tipo) {
                        operando2 = getempcode(tipo_res);
                        linha_conversao = "\t" + operando2 + " = (" + tipo_res + ") " + $6.label + ";\n";
                    }

                    string alvo = acessar_simbolo(s) + "[" + $3.label + "]";
                    string t_op = getempcode(tipo_res);
                    string op_aritmetica = "\t" + t_op + " = " + alvo + " " + $5.label.at(0) + " " + operando2 + ";\n";

                    $$.traducao = $3.traducao + $6.traducao + linha_conversao + op_aritmetica + 
                                "\t" + alvo + " = " + t_op + ";\n";
                }

                | TK_ID '[' E ']' '[' E ']' OP_COMP E ';'
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (!s.is_array || s.dim2 == 0) { yyerror("Erro: uso incorreto de matriz."); exit(1); }
                    if ($3.tipo != "int" || $6.tipo != "int") { yyerror("Erro: indices da matriz devem ser inteiros."); exit(1); }
                    
                    if (s.tipo != "int" && s.tipo != "float") {
                        yyerror("Operadores compostos so podem ser usados com int ou float.");
                        exit(1);
                    }

                    string tipo_res = get_tipo_result(s.tipo, $9.tipo);
                    if (tipo_res == "erro") { yyerror("Atribuicao composta invalida na matriz."); exit(1); }

                    // Calcula o offset da matriz
                    string t_mult = getempcode("int");
                    string t_soma = getempcode("int");
                    string calc_offset = "\t" + t_mult + " = " + $3.label + " * " + to_string(s.dim2) + ";\n"
                                       + "\t" + t_soma + " = " + t_mult + " + " + $6.label + ";\n";
                    
                    string operando2 = $9.label;
                    string linha_conversao = "";
                    if (s.tipo != $9.tipo) {
                        operando2 = getempcode(tipo_res);
                        linha_conversao = "\t" + operando2 + " = (" + tipo_res + ") " + $9.label + ";\n";
                    }

                    string alvo = acessar_simbolo(s) + "[" + t_soma + "]";
                    string t_op = getempcode(tipo_res);
                    string op_aritmetica = "\t" + t_op + " = " + alvo + " " + $8.label.at(0) + " " + operando2 + ";\n";

                    $$.traducao = $3.traducao + $6.traducao + $9.traducao + calc_offset + linha_conversao + op_aritmetica + 
                                "\t" + alvo + " = " + t_op + ";\n";
                }

                | TIPO TK_ID { declarar_variavel($2.label, $1.tipo); } '=' E ';' //atribuição + declaração
                {
                    simbolo s = buscar_simbolo($2.label);

                    string tipo_resultante = get_tipo_atribuicao(s.tipo, $5.tipo);
                    if (tipo_resultante == "erro") {
                        yyerror("Atribuicao invalida");
                        exit(1);
                    }

                    if (tipo_resultante == "string") {
                        string tsz  = getempcode("int");

                        $$.traducao = $5.traducao
                                    + "\t" + tsz  + " = __str_len(" + $5.label + ");\n"
                                    + "\t" + "free(" + s.label + ");\n"
                                    + "\t" + s.label + " = (char*) malloc(" + tsz + ");\n"
                                    + "\tstrcpy(" + s.label + ", " + $5.label + ");\n";

                    } else {
                        string linha_conversao = "";
                        string label_expressao = $5.label;
                        if (s.tipo != $5.tipo) {
                            label_expressao = getempcode(tipo_resultante);
                            linha_conversao = "\t" + label_expressao + " = (" + tipo_resultante + ") " + $5.label + ";\n";
                        }
                        $$.traducao = $5.traducao + linha_conversao + "\t" + s.label + " = " + label_expressao + ";\n";
                    }
                }

                | E ';' //Somente expressão
                {
                    $$.traducao = $1.traducao;
                }
    /* return */

|                TK_RETURN E ';'
                {
                    if (tipo_retorno_atual == "void") {
                        yyerror("Erro: funcao void nao pode retornar um valor.");
                        exit(1);
                    }

                    string tipo_resultante = get_tipo_atribuicao(tipo_retorno_atual, $2.tipo);
                    if (tipo_resultante == "erro") {
                        yyerror("Erro: tipo de retorno incompativel.");
                        exit(1);
                    }

                    string linha_conversao = "";
                    string label_retorno = $2.label;
                    if (tipo_retorno_atual != $2.tipo) {
                        label_retorno = getempcode(tipo_retorno_atual);
                        linha_conversao = "\t" + label_retorno + " = (" + tipo_retorno_atual + ") " + $2.label + ";\n";
                    }

                    $$.traducao = $2.traducao + linha_conversao + "\treturn " + label_retorno + ";\n";
                }

                | TK_RETURN ';'
                {
                    if (tipo_retorno_atual != "void") {
                        yyerror("Erro: funcao do tipo '" + tipo_retorno_atual + "' deve retornar um valor.");
                        exit(1);
                    }
                    $$.traducao = "\treturn;\n";
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
                    string alvo = acessar_simbolo(s);
                    string formato;

                    if (s.tipo == "string") {
                        string tptr = getempcode("string");
                        $$.traducao = "\t" + tptr + " = __str_read();\n"
                                    + "\t" + "free(" + alvo + ");\n"
                                    + "\t" + alvo + " = " + tptr + ";\n";
                    } else {
                        if (s.tipo == "int")   formato = "%d";
                        else if (s.tipo == "float") formato = "%f";
                        else if (s.tipo == "char")  formato = " %c";
                        else if (s.tipo == "bool")  formato = "%d";

                        $$.traducao = string("\t") + "scanf(\"" + formato + "\"," + " &" + s.label + ");\n";
                    }
                }
    /*  Bloco  */
                | BLOCO
                {
                    $$.traducao = "\n\t//{\t\n" + $1.traducao + "\t//}\n";
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
                
    /* Switch */
                | TK_SWITCH '(' E ')'
                {
                    
                    if ($3.tipo != "int" && $3.tipo != "char" && $3.tipo != "string") {
                        yyerror("Erro semântico: 'switch' aceita apenas int, char ou string.");
                        exit(1);
                    }

                    string tsw      = getempcode($3.tipo);
                    string label_fim = get_new_label();

                    pilha_sw_temp.push_back(tsw);
                    pilha_sw_fim.push_back(label_fim);
                }
                '{' CASES '}'
                {
                    string tsw      = pilha_sw_temp.back(); pilha_sw_temp.pop_back();
                    string label_fim = pilha_sw_fim.back();  pilha_sw_fim.pop_back();

                    $$.traducao = $3.traducao
                                + "\t" + tsw + " = " + $3.label + ";\n"
                                + $7.label       // testes
                                + "\tgoto " + label_fim + ";\n"
                                + $7.traducao    // corpo
                                + "\t" + label_fim + ":\n";
                }
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
                    string lc = get_new_label();
                    pilha_break.push_back(lf);
                    pilha_continue.push_back(lc);   
                }
                CORPO_CONDICIONAL TK_WHILE '(' E ')'
                {
                    if ($6.tipo != "bool") {
                        yyerror("Erro semântico: A condição do 'while' deve ser do tipo bool.");
                        exit(1);
                    }

                    string label_fim      = pilha_break.back();    pilha_break.pop_back();
                    string label_continue = pilha_continue.back(); pilha_continue.pop_back();
                    string label_inicio   = get_new_label();

                    $$.traducao = "\t" + label_inicio + ":\n"
                                + $3.traducao
                                + "\t" + label_continue + ":\n"
                                + $6.traducao
                                + "\tif (" + $6.label + ") goto " + label_inicio + ";\n"
                                + "\t" + label_fim + ":\n";
                }

    /* for */
                | TK_FOR '(' { abrir_escopo(); } FOR_INIT ';' E ';' FOR_INC ')'
                {
                    string lf  = get_new_label();
                    string linc = get_new_label(); 
                    pilha_break.push_back(lf);
                    pilha_continue.push_back(linc); 
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

                    $$.traducao = $4.traducao                                            
                                + "\t" + label_ini + ":\n"                               
                                + $6.traducao                                            
                                + "\tif (!" + $6.label + ") goto " + label_fim + ";\n"   
                                + $11.traducao                                            
                                + "\t" + label_inc + ":\n"                                
                                + $8.traducao                                             
                                + "\tgoto " + label_ini + ";\n"                           
                                + "\t" + label_fim + ":\n";                               
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
                        |   
                        {
                            $$.traducao = "";
                        }
                        ;




CORPO_CONDICIONAL   : CMD
                {
                            $$.traducao = $1.traducao;
                }
                ;


CASES   : CASES CASE_ITEM
        {
            $$.label    = $1.label    + $2.label;
            $$.traducao = $1.traducao + $2.traducao;
        }
        | CASES DEFAULT_ITEM
        {
            $$.label    = $1.label    + $2.label;
            $$.traducao = $1.traducao + $2.traducao;
        }
        |
        {
            $$.label    = "";
            $$.traducao = "";
        }
        ;

CASE_ITEM
        : TK_CASE LITERAL_CASE TK_PONTOS COMANDOS
        {
            string tsw      = pilha_sw_temp.back();
            string label_fim = pilha_sw_fim.back();

            string lb   = get_new_label();  // rótulo do corpo deste case
            string ln   = get_new_label();  // rótulo do próximo teste
            string tcmp = getempcode("bool");

            string teste;
            if ($2.tipo == "string") {
                teste = $2.traducao
                      + "\t" + tcmp + " = __str_eq(" + tsw + ", " + $2.label + ");\n"
                      + "\tif (!" + tcmp + ") goto " + ln + ";\n"
                      + "\tgoto " + lb + ";\n"
                      + "\t" + ln + ":\n";
            } else {
                teste = "\t" + tcmp + " = (" + tsw + " == " + $2.label + ");\n"
                      + "\tif (!" + tcmp + ") goto " + ln + ";\n"
                      + "\tgoto " + lb + ";\n"
                      + "\t" + ln + ":\n";
            }

            string corpo = "\t" + lb + ":\n"
                         + $4.traducao
                         + "\tgoto " + label_fim + ";\n";

            $$.label    = teste;
            $$.traducao = corpo;
        }
        ;

DEFAULT_ITEM
        : TK_DEFAULT TK_PONTOS COMANDOS
        {
            string label_fim = pilha_sw_fim.back();

            string ld = get_new_label();

            $$.label    = "\tgoto " + ld + ";\n";
            $$.traducao = "\t" + ld + ":\n"
                        + $3.traducao
                        + "\tgoto " + label_fim + ";\n";
        }
        ;

LITERAL_CASE
        : TK_INT
        {
            $$.label    = $1.label;
            $$.tipo     = "int";
            $$.traducao = "";
        }
        | TK_CHAR
        {
            $$.label    = $1.label;
            $$.tipo     = "char";
            $$.traducao = "";
        }
        | TK_STRING
        {
            string conteudo = $1.label.substr(1, $1.label.size() - 2);
            int tamanho = (int)conteudo.size() + 1;
            string tsz  = getempcode("int");
            string tptr = getempcode("string");
            $$.label    = tptr;
            $$.tipo     = "string";
            $$.traducao = "\t" + tsz  + " = " + to_string(tamanho) + ";\n"
                        + "\t" + tptr + " = (char*) malloc(" + tsz + ");\n"
                        + "\tstrcpy(" + tptr + ", " + $1.label + ");\n";
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
                    $$.label = fA + fR + "|" + vA + ", " + vR;
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
                    if($1.tipo == "int")        formato = "%d";
                    else if($1.tipo == "float") formato = "%f";
                    else if($1.tipo == "char")  formato = "%c";
                    else if($1.tipo == "bool")  formato = "%d";
                    else if($1.tipo == "string") formato = "%s";
                    
                    $$.traducao = $1.traducao; // Código intermediário gerado em E (ex: t1=2; t2=t1/b...)
                    $$.label = formato + "|" + $1.label; // "ex: %d|t3"
                }
                ;



    /* Expressão */

    /* Identificador */
E               : TK_ID
                {
                    simbolo simb = buscar_simbolo($1.label);
                    $$.label = acessar_simbolo(simb);   // antes era: simb.label
                    $$.tipo  = simb.tipo;
                    $$.traducao = "";
                }
                
    //Vetores e matrizes
                
                | TK_ID '[' E ']'
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (!s.is_array || s.dim2 != 0) { yyerror("Erro: uso incorreto de vetor (dimensionalidade)."); exit(1); }
                    if ($3.tipo != "int") { yyerror("Erro: indice do vetor deve ser inteiro."); exit(1); }
                    
                    $$.label = getempcode(s.tipo);
                    $$.tipo = s.tipo;
                    $$.traducao = $3.traducao + "\t" + $$.label + " = " + acessar_simbolo(s) + "[" + $3.label + "];\n";
                }
                
                | TK_ID '[' E ']' '[' E ']'
                {
                    simbolo s = buscar_simbolo($1.label);
                    if (!s.is_array || s.dim2 == 0) { yyerror("Erro: uso incorreto de matriz (dimensionalidade)."); exit(1); }
                    if ($3.tipo != "int" || $6.tipo != "int") { yyerror("Erro: indices da matriz devem ser inteiros."); exit(1); }
                    
                    string t_mult = getempcode("int");
                    string t_soma = getempcode("int");
                    string calc_offset = "\t" + t_mult + " = " + $3.label + " * " + to_string(s.dim2) + ";\n"
                                    + "\t" + t_soma + " = " + t_mult + " + " + $6.label + ";\n";
                                    
                    $$.label = getempcode(s.tipo);
                    $$.tipo = s.tipo;
                    $$.traducao = $3.traducao + $6.traducao + calc_offset + 
                                "\t" + $$.label + " = " + acessar_simbolo(s) + "[" + t_soma + "];\n";
                }

    /* chamada função */

                | TK_ID '(' ARGUMENTOS_CHAMADA ')'
                {
                    if (!tabela_funcoes.count($1.label)) {
                        yyerror("Erro: funcao \"" + $1.label + "\" nao declarada.");
                        exit(1);
                    }
                    funcao_info finfo = tabela_funcoes[$1.label];

                    if (finfo.tipos_param.size() != $3.lista_tipos.size()) {
                        yyerror("Erro: numero de argumentos incompativel na chamada de \"" + $1.label + "\".");
                        exit(1);
                    }

                    string trad = $3.traducao;
                    vector<string> args_finais;

                    for (size_t i = 0; i < finfo.tipos_param.size(); i++) {
                        string tparam = finfo.tipos_param[i];
                        string targ   = $3.lista_tipos[i];
                        string larg   = $3.lista_labels[i];

                        string arg_final;

                        if (tparam == "string") {
                            if (targ != "string") {
                                yyerror("Erro: argumento " + to_string(i+1) + " incompativel na chamada de \"" + $1.label + "\".");
                                exit(1);
                            }
                            arg_final = "&" + larg;   // passagem por referência
                        } else if (tparam != targ) {
                            string tipo_resultante = get_tipo_atribuicao(tparam, targ);
                            if (tipo_resultante == "erro") {
                                yyerror("Erro: argumento " + to_string(i+1) + " incompativel na chamada de \"" + $1.label + "\".");
                                exit(1);
                            }
                            string conv = getempcode(tparam);
                            trad += "\t" + conv + " = (" + tparam + ") " + larg + ";\n";
                            arg_final = conv;
                        } else {
                            arg_final = larg;
                        }

                        args_finais.push_back(arg_final);
                    }

                    string lista_args = "";
                    for (size_t i = 0; i < args_finais.size(); i++) {
                        if (i > 0) lista_args += ", ";
                        lista_args += args_finais[i];
                    }

                    $$.tipo = finfo.tipo_retorno;

                    if (finfo.tipo_retorno == "void") {
                        $$.label = "";
                        $$.traducao = trad + "\t" + finfo.label + "(" + lista_args + ");\n";
                    } else {
                        $$.label = getempcode(finfo.tipo_retorno);
                        $$.traducao = trad + "\t" + $$.label + " = " + finfo.label + "(" + lista_args + ");\n";
                    }
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

                | TK_STRING
                {
                    string conteudo = $1.label.substr(1, $1.label.size() - 2);
                    int tamanho = (int)conteudo.size() + 1; // +1 para '\0'

                    string tsz  = getempcode("int");
                    string tptr = getempcode("string");
                    $$.label   = tptr;
                    $$.tipo    = "string";
                    $$.tamanho = tamanho;
                    $$.traducao = "\t" + tsz  + " = " + to_string(tamanho) + ";\n"
                                + "\t" + tptr + " = (char*) malloc(" + tsz + ");\n"
                                + "\tstrcpy(" + tptr + ", " + $1.label + ");\n";
                }
    /*    Operadores aritméticos   */

                | E '+' E
                {
                    string tipo_resultante = get_tipo_result($1.tipo, $3.tipo);

                    if (tipo_resultante == "erro") {
                        yyerror("Operacao com soma invalida");
                        exit(1);
                    }

                    if (tipo_resultante == "string") {
                        // Concatenação: string+string, string+char, char+string, char+char
                        // Precisamos de buffers temporários de char* para os dois operandos
                        string op1_ptr = $1.label;
                        string op2_ptr = $3.label;
                        string trad_conv = $1.traducao + $3.traducao;

                        // Se E1 é char, converter para string temporária de 2 bytes
                        if ($1.tipo == "char") {
                            string tbuf1 = getempcode("string");
                            trad_conv += "\t" + tbuf1 + " = (char*) malloc(2);\n";
                            trad_conv += "\t" + tbuf1 + "[0] = " + op1_ptr + ";\n";
                            trad_conv += "\t" + tbuf1 + "[1] = '\\0';\n";
                            op1_ptr = tbuf1;
                        }

                        // Se E2 é char, converter para string temporária de 2 bytes
                        if ($3.tipo == "char") {
                            string tbuf2 = getempcode("string");
                            trad_conv += "\t" + tbuf2 + " = (char*) malloc(2);\n";
                            trad_conv += "\t" + tbuf2 + "[0] = " + op2_ptr + ";\n";
                            trad_conv += "\t" + tbuf2 + "[1] = '\\0';\n";
                            op2_ptr = tbuf2;
                        }

                        // Calcular tamanhos e alocar resultado
                        string tsz1   = getempcode("int");
                        string tsz2   = getempcode("int");
                        string tsz_r  = getempcode("int");
                        string tresult = getempcode("string");

                        trad_conv += "\t" + tsz1  + " = __str_len(" + op1_ptr + ");\n";
                        trad_conv += "\t" + tsz2  + " = __str_len(" + op2_ptr + ");\n";
                        trad_conv += "\t" + tsz_r + " = " + tsz1 + " + " + tsz2 + ";\n";
                        trad_conv += "\t" + tresult + " = (char*) malloc(" + tsz_r + ");\n";
                        trad_conv += "\tstrcpy(" + tresult + ", " + op1_ptr + ");\n";
                        trad_conv += "\tstrcat(" + tresult + ", " + op2_ptr + ");\n";

                        $$.label    = tresult;
                        $$.tipo     = "string";
                        $$.tamanho  = 0; // tamanho dinâmico; calculado em runtime
                        $$.traducao = trad_conv;
                    } else {
                        string linha_conversao = "";
                        string operando1 = $1.label;
                        string operando2 = $3.label;

                        linha_conversao = aplicar_coercao($1, $3, operando1, operando2, tipo_resultante);

                        $$.label = getempcode(tipo_resultante);
                        $$.tipo = tipo_resultante;
                        $$.traducao = $1.traducao + $3.traducao + linha_conversao +
                            "\t" + $$.label + " = " + operando1 + " + " + operando2 + ";\n";
                    }
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
                    if($2.tipo != "int" && $2.tipo != "float" ){
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
                    if($2.tipo == "bool" || $2.tipo == "string"){
                        yyerror("Operacao de cast invalida");
                        exit(1);
                    }
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

ARGUMENTOS_CHAMADA : ARGUMENTOS_CHAMADA ',' ARG_CHAMADA
                    {
                        $$.traducao = $1.traducao + $3.traducao;
                        $$.lista_tipos  = $1.lista_tipos;
                        $$.lista_labels = $1.lista_labels;
                        $$.lista_tipos.push_back($3.tipo);
                        $$.lista_labels.push_back($3.label);
                    }
                    | ARG_CHAMADA
                    {
                        $$.traducao = $1.traducao;
                        $$.lista_tipos.clear();
                        $$.lista_labels.clear();
                        $$.lista_tipos.push_back($1.tipo);
                        $$.lista_labels.push_back($1.label);
                    }
                    |
                    {
                        $$.traducao = "";
                        $$.lista_tipos.clear();
                        $$.lista_labels.clear();
                    }
                    ;

ARG_CHAMADA         : E
                    {
                        $$.tipo     = $1.tipo;
                        $$.label    = $1.label;
                        $$.traducao = $1.traducao;
                    }
                    ;


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
    if (tipo == "void") {
        yyerror("Erro: nao e permitido declarar variavel do tipo 'void'.");
        exit(1);
    }


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


void declarar_parametro(string nome, string tipo, bool is_array = false){
    if (tipo == "void") {
        yyerror("Erro: parametro nao pode ser do tipo 'void'.");
        exit(1);
    }
    if (pilha_tabelas.back().count(nome)) {
        yyerror("Erro: parametro \"" + nome + "\" duplicado.");
        exit(1);
    }

    simbolo s;
    s.tipo       = tipo;
    s.label      = "p_" + nome;
    s.escopo     = "parametro";
    s.is_array   = is_array; // Marca na tabela de símbolos que este parâmetro é um array
    
    s.referencia = (tipo == "string") && !is_array; 
    
    pilha_tabelas.back()[nome] = s;

    declaracao_aux d = {tipo, s.label, nome, is_array, 0};
    parametros_atual.push_back(d);
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


string acessar_simbolo(const simbolo& s) {
    if (s.referencia) {
        return "(*" + s.label + ")";
    }
    return s.label;
}


string gerar_preambulo() {
    string s = "";
    s += "#include <stdio.h>\n";
    s += "#include <stdlib.h>\n";
    s += "#include <string.h>\n";
    s += "#define true 1\n";
    s += "#define false 0\n";
    s += "#define bool int\n";
    s += "\n";

    s += "int __str_len(char *s) {\n";
    s += "\tint i;\n";
    s += "\ti = 0;\n";
    s += "\tL_sl_loop:\n";
    s += "\tchar c = s[i];\n";
    s += "\tbool a1;\n";
    s += "\ta1 = c == '\\0';\n";
    s += "\tif (a1) goto L_sl_end;\n";
    s += "\ti = i + 1;\n";
    s += "\tgoto L_sl_loop;\n";
    s += "\tL_sl_end:\n";
    s += "\ti = i + 1;\n";
    s += "\treturn i;\n";
    s += "}\n";
    s += "\n";

    s += "/* Retorna 1 se iguais, 0 se diferentes */\n";
    s += "bool __str_eq(char *a, char *b) {\n";
    s += "\tint i;\n";
    s += "\tchar ca;\n";
    s += "\tchar cb;\n";
    s += "\tbool eq;\n";
    s += "\tbool fim;\n";
    s += "\ti = 0;\n";
    s += "\tL_se_loop:\n";
    s += "\tca = a[i];\n";
    s += "\tcb = b[i];\n";
    s += "\teq = ca == cb;\n";
    s += "\tif (!eq) goto L_se_false;\n";
    s += "\tfim = ca == '\\0';\n";
    s += "\tif (fim) goto L_se_true;\n";
    s += "\ti = i + 1;\n";
    s += "\tgoto L_se_loop;\n";
    s += "\tL_se_true:\n";
    s += "\treturn 1;\n";
    s += "\tL_se_false:\n";
    s += "\treturn 0;\n";
    s += "}\n";
    s += "\n";

    s += "char* __str_read() {\n";
    s += "\tint cap;\n";
    s += "\tint len;\n";
    s += "\tint next;\n";
    s += "\tchar *buf;\n";
    s += "\tchar c;\n";
    s += "\tchar *tmp;\n";
    s += "\tbool a1;\n";
    s += "\tbool a2;\n";
    s += "\tbool a3;\n";
    s += "\tcap = 32;\n";
    s += "\tlen = 0;\n";
    s += "\tbuf = (char*) malloc(cap);\n";
    s += "\tL_sr_loop:\n";
    s += "\tc = getchar();\n";
    s += "\ta1 = c == '\\n';\n";
    s += "\tif (a1) goto L_sr_end;\n";
    s += "\ta2 = c == EOF;\n";
    s += "\tif (a2)  goto L_sr_end;\n";
    s += "\tnext = len + 1;\n";
    s += "\ta3 = next < cap;\n";
    s += "\tif (a3) goto L_sr_store;\n";
    s += "\tcap = cap + cap;\n";
    s += "\ttmp = (char*) malloc(cap);\n";
    s += "\tstrcpy(tmp, buf);\n";
    s += "\tfree(buf);\n";
    s += "\tbuf = tmp;\n";
    s += "\tL_sr_store:\n";
    s += "\tbuf[len] = c;\n";
    s += "\tlen = len + 1;\n";
    s += "\tgoto L_sr_loop;\n";
    s += "\tL_sr_end:\n";
    s += "\tbuf[len] = '\\0';\n";
    s += "\treturn buf;\n";
    s += "}\n";
    s += "\n";
    return s;
}

void declarar_array(string nome, string tipo, int dim1, int dim2) {
    if (tipo == "void") {
        yyerror("Erro: array nao pode ser do tipo 'void'."); exit(1);
    }
    if(pilha_tabelas.back().count(nome)){
        yyerror("Erro: Variável \"" + nome + "\" já declarada neste escopo"); exit(1);
    }
    
    simbolo simb;
    simb.tipo = tipo;
    simb.is_array = true;
    simb.dim1 = dim1;
    simb.dim2 = dim2;
    int tamanho_total = (dim2 == 0) ? dim1 : (dim1 * dim2); // Mapeamento linear

    if (pilha_tabelas.size() == 1) {
        simb.label = "g_" + nome;
        simb.escopo = "global";
        pilha_tabelas.back()[nome] = simb;
        declaracao_aux decl = {tipo, simb.label, nome, true, tamanho_total};
        todas_variaveis_globais.push_back(decl);
    } else {
        simb.label = "u_" + nome + "_escopo" + to_string(contador_escopos);
        simb.escopo = "local";
        pilha_tabelas.back()[nome] = simb;
        declaracao_aux decl = {tipo, simb.label, nome, true, tamanho_total};
        todas_variaveis_locais.push_back(decl);
    }
}

string gerar_declaracoes_globais(){
    string texto = "";
    for(auto const& decl : todas_variaveis_globais) {
        if(decl.is_array) {
            if(decl.tipo == "string") 
                texto += "char* " + decl.label + "[" + to_string(decl.tamanho_total) + "]; // global user:" + decl.id_original + "\n";
            else 
                texto += decl.tipo + " " + decl.label + "[" + to_string(decl.tamanho_total) + "]; // global user:" + decl.id_original + "\n";
        } else {
            if(decl.tipo == "string") {
                texto += "char* " + decl.label + " = NULL; // global user:" + decl.id_original + "\n";
            } else {
                string inicializacao = " = 0;";
                if(decl.tipo == "float") inicializacao = " = 0.0;";
                else if(decl.tipo == "bool") inicializacao = " = false;";
                else if(decl.tipo == "char") inicializacao = " = ' ';";
                texto += decl.tipo + " " + decl.label + inicializacao + " // global user:" + decl.id_original + "\n";
            }
        }
    }
    return texto;
}

string gerar_declaracoes_locais(){
    string texto = "";
    
    for(auto const& decl : todas_variaveis_locais) {
            if(decl.is_array) {
                if(decl.tipo == "string") 
                    texto += "\tchar* " + decl.label + "[" + to_string(decl.tamanho_total) + "]; // local user:" + decl.id_original + "\n";
                else 
                    texto += "\t" + decl.tipo + " " + decl.label + "[" + to_string(decl.tamanho_total) + "]; // local user:" + decl.id_original + "\n";
            } else {
                if(decl.tipo == "string")
                    texto += "\tchar* " + decl.label + "; // local user:" + decl.id_original + "\n";
                else
                    texto += "\t" + decl.tipo + " " + decl.label + "; // local user:" + decl.id_original + "\n";
            }
    }

    for(int i = 1; i <= (int)tipos_temporarios.size(); i++){
        string t = tipos_temporarios[i-1];
        if(t == "string")
            texto += "\tchar* t" + to_string(i) + ";\n";
        else
            texto += "\t" + t + " t" + to_string(i) + ";\n";
    }

    for(auto const& decl : todas_variaveis_locais) {
        if (decl.is_array) {
            // Define o valor padrão com base no tipo
            string valor_init = "0";
            if(decl.tipo == "float") valor_init = "0.0";
            else if(decl.tipo == "bool") valor_init = "false";
            else if(decl.tipo == "char") valor_init = "' '";
            else if(decl.tipo == "string") valor_init = "NULL";

            string iterador = "_i_" + decl.label;
            string label_inicio = "L_init_start_" + decl.label;
            string label_fim = "L_init_end_" + decl.label;

            texto += "\n\t// Inicialização do array " + decl.id_original + "\n";

            texto += "\tint " + iterador + " = 0;\n";
            
            texto += "\t" + label_inicio + ":\n";
            texto += "\tif (" + iterador + " >= " + to_string(decl.tamanho_total) + ") goto " + label_fim + ";\n";
            texto += "\t" + decl.label + "[" + iterador + "] = " + valor_init + ";\n";
            texto += "\t" + iterador + " = " + iterador + " + 1;\n";
            texto += "\tgoto " + label_inicio + ";\n";
            texto += "\t" + label_fim + ":\n";
            
            continue;
        }

        texto += "\n\t// Inicialização da variável " + decl.id_original + "\n";
        if(decl.tipo == "int")
            texto += "\t" + decl.label + " = 0;\n";
        else if(decl.tipo == "float")
            texto += "\t" + decl.label + " = 0.0;\n";
        else if(decl.tipo == "bool")
            texto += "\t" + decl.label + " = false;\n";
        else if(decl.tipo == "char")
            texto += "\t" + decl.label + " = ' ';\n";
        else if(decl.tipo == "string")
            texto += "\t" + decl.label + " = NULL;\n";
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