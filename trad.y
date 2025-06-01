/* Viktor Doronin, Adrian Martinez Cruz, Grupo 614 */
/* 100450631@alumnos.uc3m.es 100451213@alumnos.uc3m.es */
%{                          // SECCION 1 Declaraciones de C-Yacc

#include <stdio.h>
#include <ctype.h>            // declaraciones para tolower
#include <string.h>           // declaraciones para cadenas
#include <stdlib.h>           // declaraciones para exit ()

#define FF fflush(stdout);    // para forzar la impresion inmediata

int yylex () ;
int yyerror () ;
char *mi_malloc (int) ;
char *gen_code (char *) ;
char *int_to_string (int) ;
char *char_to_string (char) ;

char temp [2048] ;
char currfunc [64];
char if_temp[2048] = "";
 char funcarg[64];

//symbol table
char* symbols[64];
int sym_cnt;
int search_symbol (char *symbol_name)
{                                  // Busca n_s en la tabla de pal. res.
                                   // y devuelve puntero a registro (simbolo)
    int i ;

    i = 0 ;
    while (symbols [i] != NULL) {
	    if (strcmp (symbols[i], symbol_name) == 0) {
		                             // strcmp(a, b) devuelve == 0 si a==b
            return 1 ;
        }
        i++ ;
    }

    return 0 ;
}
// Abstract Syntax Tree (AST) Node Structure

typedef struct ASTnode t_node ;

struct ASTnode {
    char *op ;
    int type ;		// leaf, unary or binary nodes
    t_node *left ;
    t_node *right ;
} ;


// Definitions for explicit attributes

typedef struct s_attr {
    int value ;    // - Numeric value of a NUMBER 
    char *code ;   // - to pass IDENTIFIER names, and other translations 
    t_node *node ; // - for possible future use of AST
} t_attr ;

int progn; //line counter for if-else
 
#define YYSTYPE t_attr

%}

// Definitions for explicit attributes

%token NUMBER        
%token IDENTIF       // Identificador=variable
%token INTEGER       // identifica el tipo entero
%token STRING
%token MAIN          // identifica el comienzo del proc. main
%token WHILE         // identifica el bucle main
%token PUTS
%token FOR
%token IF
%token ELSE
%token PRINTF
%token RETURN

%right '='                    // es la ultima operacion que se debe realizar
%left '+' '-'                 // menor orden de precedencia
%left '*' '/' '%'                 // orden de precedencia intermedio
%left UNARY_SIGN              // mayor orden de precedencia

%%                            // Seccion 3 Gramatica - Semantico


axioma:         program { ; }

            ;

program:        globals     { printf("%s", $1.code); } funcs { sym_cnt = 0; memset(symbols, 0, sizeof(symbols));
                                printf("%s", $3.code); } MAIN { sprintf(currfunc,"main_") ; } '(' ')' '{' code '}'
                                { printf("(defun main()\n%s\n)\n", $10.code) ; }

            ;
lambda:         { sprintf(temp, "");
                    $$.code = gen_code(temp) ; }

            ;

funcs:          lambda

            |   func      { sym_cnt = 0; memset(symbols, 0, sizeof(symbols)); 
                            memset(currfunc, 0, sizeof(currfunc)); } funcs { sprintf(temp, "%s%s", $1.code, $3.code);
                            $$.code=gen_code(temp); }

            ;

func:           IDENTIF     { sprintf(currfunc, "%s_", $1.code); } '(' arg {sprintf(funcarg, "%s", $4.code); }')' '{' code ret '}'
                            { sprintf(temp,"(defun %s(%s)\n%s\n%s\n)\n", $1.code, $4.code, $8.code, $9.code);
                                $$.code = gen_code(temp) ; }

            ;

arg:            lambda

            | INTEGER IDENTIF   { $$.code = $2.code;
                                    symbols[sym_cnt] = malloc(64);
                                    sprintf(symbols[sym_cnt], "%s", $2.code);
                                    sym_cnt++; sprintf(funcarg, "%s", $2.code) ; }

            ;

ret:            lambda

            |   RETURN IDENTIF ';' { $$.code = $2.code ; }

            ;

globals:        lambda

            |   decvar ';' globals { sprintf(temp, "%s%s", $1.code, $3.code) ;
                                        $$.code = gen_code(temp) ; }
            
            ;

decvar:         INTEGER dec     { sprintf(temp, "%s", $2.code);
                                    $$.code = gen_code(temp) ; }

            |   makevec         { sprintf(temp, "%s\n", $1.code);
                                    $$.code = gen_code(temp) ; }
            
            ;

dec:            var restdec { sprintf(temp, "%s%s", $1.code, $2.code);
                                $$.code = gen_code(temp) ; }

            ;

restdec:        lambda

            | ',' dec  { $$ = $2 ; }

            ;

var:            IDENTIF restvar { sprintf(temp, "(setq %s %d)\n", $1.code, $2.value);
                                    $$.code = gen_code(temp) ; }

            ;

restvar:        /* lambda */ { $$.value=0 ; }

            |   '=' NUMBER { $$ = $2 ; }

            ;

code:           sentencia  r_code   { sprintf (temp,"%s%s", $1.code, $2.code);
                                        $$.code = gen_code(temp) ; }

            ;

r_code:         lambda

            |   code                   { progn=1;sprintf (temp,"\n%s", $1.code);
                                            $$.code = gen_code(temp) ; }

            ;

sentencia:      assign ';' { $$=$1;  }

            |   '@' expresion ';'       { sprintf (temp, "(print %s)", $2.code);  
                                                $$.code = gen_code (temp) ; }
                                                    
            |   PUTS '(' STRING ')' ';' { sprintf (temp, "(print \"%s\")", $3.code); 
                                                $$.code = gen_code (temp) ; }
                                                    
            |   PRINTF '(' STRING ',' printelems ')' ';' { $$ = $5 ; }

            |   WHILE '(' condition ')' '{' code '}'    { sprintf (temp, "(loop while %s do %s)", $3.code, $6.code);
                                                            $$.code = gen_code (temp) ; }
            
            |   IF '(' condition ')' '{' code '}'   { if (!progn) { sprintf (if_temp, "(if %s \n%s", $3.code, $6.code) ; }
                                                        else { sprintf (if_temp, "(if %s \nprogn(%s)", $3.code, $6.code); } progn = 0 ; } 
                                                        elseexpr { sprintf(temp, "%s%s)", if_temp, $9.code);
                                                        $$.code = gen_code(temp) ; progn = 0 ; }
            
            |   FOR '(' assign ';' condition ';' incr ')' '{' code '}' { sprintf (temp, "%s\n(loop while %s do\n%s\n%s)", $3.code, $5.code, $10.code, $7.code);
                                                                            $$.code = gen_code (temp) ; }

            |   func_call ';'   { $$ = $1 ; }

            |   makevec ';'     { $$ = $1 ; }
            
            ;

incr:           IDENTIF '+' '=' NUMBER  { sprintf (temp, "(+ %s%s %d)", currfunc,$1.code, $4.value);
                                            $$.code = gen_code (temp) ; }
|               IDENTIF '-' '=' NUMBER  { sprintf (temp, "(+ %s%s %d)", currfunc,$1.code, $4.value);
                                            $$.code = gen_code (temp) ; }
;
   
assign:         INTEGER IDENTIF '=' expresion       { if(search_symbol($2.code)){sprintf (temp, "(setf %s%s %s)", currfunc, $2.code, $4.code) ; }
                                                        else { symbols[sym_cnt] = malloc(64);
                                                        sprintf(symbols[sym_cnt],"%s", $2.code); sym_cnt++;
                                                        sprintf (temp, "(setq %s%s %s)", currfunc, $2.code, $4.code) ; }
                                                        $$.code = gen_code (temp) ; }
                                                        
            |   IDENTIF '=' expresion               { if(search_symbol($1.code)){sprintf (temp, "(setf %s%s %s)", currfunc, $1.code, $3.code) ; }
                                                        else { symbols[sym_cnt] = malloc(64);sprintf(symbols[sym_cnt],"%s", $1.code); sym_cnt++;
                                                        sprintf (temp, "(setq %s%s %s)", currfunc, $1.code, $3.code) ; }
                                                        $$.code = gen_code (temp) ; }
                                                        
            |   vec '=' expresion                   { sprintf(temp,"(setf (aref %s %d) %s)", $1.code, $1.value, $3.code);
                                                        $$.code = gen_code(temp) ; }

            ;

vec:            IDENTIF '[' NUMBER ']'  { $$.code = $1.code; $1.value = $3.value ; }
            ;

makevec:        INTEGER vec { sprintf(temp, "(setq %s (make-array %d))", $2.code, $2.value);
                                $$.code = gen_code(temp) ; }
            ;

elseexpr:       lambda

            |   ELSE '{' code '}'   { if(!progn){sprintf(temp,"\n%s",$3.code) ; } 
                                        else {sprintf(temp,"\nprogn(%s)",$3.code) ; }
                                        $$.code = gen_code(temp); progn = 0 ; }
                                        
            ;

printelems:     STRING r_elem       { sprintf(temp,"(princ %s)\n%s", $1.code, $2.code);
                                        $$.code = gen_code(temp) ; }

            |   expresion r_elem    { sprintf(temp,"(princ %s)\n%s", $1.code, $2.code);
                                        $$.code = gen_code(temp) ; }
                                        
            ;


r_elem:         lambda

            |   ',' printelems      { $$ = $2 ; }
            
            ;

condition:      cond_expr '=''=' expresion  { sprintf (temp,"(= %s %s)", $1.code, $4.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '&''&' expresion  { sprintf (temp,"(and %s %s)", $1.code, $4.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '|''|' expresion  { sprintf (temp,"(or %s %s)", $1.code, $4.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '!''=' expresion  { sprintf (temp,"(/= %s %s)", $1.code, $4.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '!' expresion     { sprintf (temp,"(not %s %s)", $1.code, $3.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '<' expresion     { sprintf (temp,"(< %s %s)", $1.code, $3.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '<''=' expresion  { sprintf (temp,"(<= %s %s)", $1.code, $4.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '>''=' expresion  { sprintf (temp,"(>= %s %s)", $1.code, $4.code) ;$$.code = gen_code(temp) ; }

            |   cond_expr '>' expresion     { sprintf (temp,"(> %s %s)", $1.code, $3.code) ;$$.code = gen_code(temp) ; }

            ;

cond_expr:      condition {$$ = $1;}

            |   expresion {$$ = $1;}
            
            ;

expresion:      termino                     { $$ = $1 ; }

            |   expresion '+' expresion     { sprintf (temp, "(+ %s %s)", $1.code, $3.code);
                                                $$.code = gen_code (temp) ; }

            |   expresion '-' expresion     { sprintf (temp, "(- %s %s)", $1.code, $3.code);
                                                $$.code = gen_code (temp) ; }

            |   expresion '*' expresion     { sprintf (temp, "(* %s %s)", $1.code, $3.code);
                                                $$.code = gen_code (temp) ; }

            |   expresion '/' expresion     { sprintf (temp, "(/ %s %s)", $1.code, $3.code);
                                                $$.code = gen_code (temp) ; }

            |   func_call                   { $$ = $1 ; }

            |   expresion '%' expresion     { sprintf (temp, "(mod %s %s)", $1.code, $3.code);  
                                                $$.code = gen_code (temp) ; }
            ;

func_call:      IDENTIF '(' operando ')'    { sprintf(temp,"(%s %s)", $1.code, $3.code);
                                                $$.code=gen_code(temp) ; }

            ;

termino:        operando                           { $$ = $1 ; }
                         
            |   '+' operando %prec UNARY_SIGN      { $$ = $1 ; }

            |   '-' operando %prec UNARY_SIGN      { sprintf (temp, "(- %s)", $2.code);
                                                        $$.code = gen_code (temp) ; }    
            ;

operando:       IDENTIF                 { if (strcmp(funcarg,$1.code)!=0){sprintf (temp, "%s%s",currfunc,$1.code) ; } 
                                            else { sprintf (temp, "%s",$1.code);} $$.code = gen_code (temp) ; }
                                        
            |   NUMBER                  { sprintf (temp, "%d", $1.value);
                                            $$.code = gen_code (temp) ; }
                                           
            |   '(' expresion ')'       { $$ = $2 ; }
            
            |   vec                       { sprintf(temp,"(aref %s %d)",$1.code, $1.value);
                                            $$.code=gen_code(temp) ; }

            ;


%%                            // SECCION 4    Codigo en C

int n_line = 1 ;

int yyerror (mensaje)
char *mensaje ;
{
    fprintf (stderr, "%s en la linea %d\n", mensaje, n_line) ;
    printf ( "\n") ;	// bye
}

char *int_to_string (int n)
{
    sprintf (temp, "%d", n) ;
    return gen_code (temp) ;
}

char *char_to_string (char c)
{
    sprintf (temp, "%c", c) ;
    return gen_code (temp) ;
}

char *my_malloc (int nbytes)       // reserva n bytes de memoria dinamica
{
    char *p ;
    static long int nb = 0;        // sirven para contabilizar la memoria
    static int nv = 0 ;            // solicitada en total

    p = malloc (nbytes) ;
    if (p == NULL) {
        fprintf (stderr, "No queda memoria para %d bytes mas\n", nbytes) ;
        fprintf (stderr, "Reservados %ld bytes en %d llamadas\n", nb, nv) ;
        exit (0) ;
    }
    nb += (long) nbytes ;
    nv++ ;

    return p ;
}


/***************************************************************************/
/********************** Seccion de Palabras Reservadas *********************/
/***************************************************************************/



typedef struct s_keyword { // para las palabras reservadas de C
    char *name ;
    int token ;
} t_keyword ;

t_keyword keywords [] = { // define las palabras reservadas y los
    "main",        MAIN,           // y los token asociados
    "int",         INTEGER,
    "puts",        PUTS,
    "printf",      PRINTF,
    "while",       WHILE,
    "if",          IF,
    "else",        ELSE,
    "for",         FOR,
    "return",      RETURN,
    NULL,          0               // para marcar el fin de la tabla
} ;

t_keyword *search_keyword (char *symbol_name)
{                                  // Busca n_s en la tabla de pal. res.
                                   // y devuelve puntero a registro (simbolo)
    int i ;
    t_keyword *sim ;

    i = 0 ;
    sim = keywords ;
    while (sim [i].name != NULL) {
	    if (strcmp (sim [i].name, symbol_name) == 0) {
		                             // strcmp(a, b) devuelve == 0 si a==b
            return &(sim [i]) ;
        }
        i++ ;
    }

    return NULL ;
}

 
/***************************************************************************/
/******************* Seccion del Analizador Lexicografico ******************/
/***************************************************************************/

char *gen_code (char *name)     // copia el argumento a un
{                                      // string en memoria dinamica
    char *p ;
    int l ;
	
    l = strlen (name)+1 ;
    p = (char *) my_malloc (l) ;
    strcpy (p, name) ;
	
    return p ;
}


int yylex ()
{
// NO MODIFICAR ESTA FUNCION SIN PERMISO
    int i ;
    unsigned char c ;
    unsigned char cc ;
    char ops_expandibles [] = "!<=|>%&/+-*" ;
    char temp_str [256] ;
    t_keyword *symbol ;

    do {
        c = getchar () ;

        if (c == '#') {	// Ignora las lineas que empiezan por #  (#define, #include)
            do {		//	OJO que puede funcionar mal si una linea contiene #
                c = getchar () ;
            } while (c != '\n') ;
        }

        if (c == '/') {	// Si la linea contiene un / puede ser inicio de comentario
            cc = getchar () ;
            if (cc != '/') {   // Si el siguiente char es /  es un comentario, pero...
                ungetc (cc, stdin) ;
            } else {
                c = getchar () ;	// ...
                if (c == '@') {	// Si es la secuencia //@  ==> transcribimos la linea
                    do {		// Se trata de codigo inline (Codigo embebido en C)
                        c = getchar () ;
                        putchar (c) ;
                    } while (c != '\n') ;
                } else {		// ==> comentario, ignorar la linea
                    while (c != '\n') {
                        c = getchar () ;
                    }
                }
            }
        } else if (c == '\\') c = getchar () ;
		
        if (c == '\n')
            n_line++ ;

    } while (c == ' ' || c == '\n' || c == 10 || c == 13 || c == '\t') ;

    if (c == '\"') {
        i = 0 ;
        do {
            c = getchar () ;
            temp_str [i++] = c ;
        } while (c != '\"' && i < 255) ;
        if (i == 256) {
            printf ("AVISO: string con mas de 255 caracteres en linea %d\n", n_line) ;
        }		 	// habria que leer hasta el siguiente " , pero, y si falta?
        temp_str [--i] = '\0' ;
        yylval.code = gen_code (temp_str) ;
        return (STRING) ;
    }

    if (c == '.' || (c >= '0' && c <= '9')) {
        ungetc (c, stdin) ;
        scanf ("%d", &yylval.value) ;
//         printf ("\nDEV: NUMBER %d\n", yylval.value) ;        // PARA DEPURAR
        return NUMBER ;
    }

    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
        i = 0 ;
        while (((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '_') && i < 255) {
            temp_str [i++] = tolower (c) ;
            c = getchar () ;
        }
        temp_str [i] = '\0' ;
        ungetc (c, stdin) ;

        yylval.code = gen_code (temp_str) ;
        symbol = search_keyword (yylval.code) ;
        if (symbol == NULL) {    // no es palabra reservada -> identificador antes vrariabre
//               printf ("\nDEV: IDENTIF %s\n", yylval.code) ;    // PARA DEPURAR
            return (IDENTIF) ;
        } else {
//               printf ("\nDEV: OTRO %s\n", yylval.code) ;       // PARA DEPURAR
            return (symbol->token) ;
        }
    }

    if (strchr (ops_expandibles, c) != NULL) { // busca c en ops_expandibles
        cc = getchar () ;
        sprintf (temp_str, "%c%c", (char) c, (char) cc) ;
        symbol = search_keyword (temp_str) ;
        if (symbol == NULL) {
            ungetc (cc, stdin) ;
            yylval.code = NULL ;
            return (c) ;
        } else {
            yylval.code = gen_code (temp_str) ; // aunque no se use
            return (symbol->token) ;
        }
    }

//    printf ("\nDEV: LITERAL %d #%c#\n", (int) c, c) ;      // PARA DEPURAR
    if (c == EOF || c == 255 || c == 26) {
//         printf ("tEOF ") ;                                // PARA DEPURAR
        return (0) ;
    }

    return c ;
}


int main ()
{
    yyparse () ;
}
