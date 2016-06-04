/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
    YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comments_depth = 0;
int string_length = 0;
void reset_string();
bool string_too_long();
int string_length_error();
void string_add(char* str);


%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
DIGIT           [0-9]
LETTER          [a-zA-Z0-9_]


%x COMMENT
%x STRING
%x BROKENSTRING

%%

<INITIAL,COMMENT>"(*" {
  comments_depth ++;
  BEGIN(COMMENT);
}

<COMMENT>\n {
  curr_lineno++;
}
<COMMENT>. {}

<COMMENT>"*)" {
  comments_depth--;
  if(comments_depth == 0) {
    BEGIN(INITIAL);
  }
}

<COMMENT><<EOF>> {
  BEGIN(INITIAL);
  cool_yylval.error_msg = "Unexpect eof in comments";
  return(ERROR);
}

<INITIAL>"*)" {
  cool_yylval.error_msg = "Unexpect *)";
  return(ERROR);
}

"--".*\n {curr_lineno++;}
"--".* {curr_lineno++;}


 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */
{DARROW}        { return (DARROW); }
"<-"            { return (ASSIGN); }
"<="            { return (LE); }
"/"             { return '/'; }
"+"             { return '+'; }
"-"             { return '-'; }
"*"             { return '*'; }
"("             { return '('; }
")"             { return ')'; }
"="             { return '='; }
"<"             { return '<'; }
"."             { return '.'; }
"~"             { return '~'; }
","             { return ','; }
";"             { return ';'; }
":"             { return ':'; }
"@"             { return '@'; }
"{"             { return '{'; }
"}"             { return '}'; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)      { return(CLASS); }
(?i:else)       { return(ELSE); }
(?i:fi)         { return(FI); }
(?i:if)         { return(IF); }
(?i:in)         { return(IN); }
(?i:inherits)   { return(INHERITS); }
(?i:let)        { return(LET); }
(?i:loop)       { return(LOOP); }
(?i:pool)       { return(POOL); }
(?i:then)       { return(THEN); }
(?i:while)      { return(WHILE); }
(?i:case)       { return(CASE); }
(?i:esac)       { return(ESAC); }
(?i:of)         { return(OF); }
(?i:new)        { return(NEW); }
(?i:isvoid)     { return(ISVOID); }
(?i:not)        { return(NOT); }

t(?i:rue)       {
                  cool_yylval.boolean = true;
                  return(BOOL_CONST);
                }
f(?i:alse)      { 
                  cool_yylval.boolean = false;
                  return(BOOL_CONST);
                }

{DIGIT}+        {
                  cool_yylval.symbol = inttable.add_string(yytext);
                  return(INT_CONST);
                }

[A-Z]{LETTER}*  {
                  cool_yylval.symbol = idtable.add_string(yytext);
                  return(TYPEID);
                }
[a-z]{LETTER}*  {
                  cool_yylval.symbol = idtable.add_string(yytext);
                  return(OBJECTID);
                }
 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

\" {
  BEGIN(STRING);
}

<STRING>\" {
  cool_yylval.symbol = stringtable.add_string(string_buf);
  reset_string();
  BEGIN(INITIAL);
  return(STR_CONST);
}

<BROKENSTRING>.*[\"\n] {
  BEGIN(INITIAL);
}

<STRING><<EOF>> {
  reset_string();
  cool_yylval.error_msg = "Unexpect eof in String";
  BEGIN(INITIAL);
  return (ERROR);
}

<STRING>(\0|\\\0) {
  reset_string();
  cool_yylval.error_msg = "Unexpect null in string";
  BEGIN(BROKENSTRING);
  return(ERROR);
}

<STRING>\\\n      {   
                    if (string_too_long()) { return string_length_error(); }
                    curr_lineno++; 
                    string_add("\n");
                    string_length++;
                    // printf("buffer: %s\n", string_buf);
                }

<STRING>\n {
  curr_lineno++;
  reset_string();
  cool_yylval.error_msg = "Unfinished String";
  BEGIN(INITIAL);
  return(ERROR);
}

<STRING>\\n {
  if(string_too_long()) {return string_length_error();}
  curr_lineno++;
  string_add("\n");
}

<STRING>\\t {
  if(string_too_long()) {return string_length_error();}
  string_length++;
  string_add("\t");
}

<STRING>\\b {
  if(string_too_long()) {return string_length_error();}
  string_length++;
  string_add("\b");
}

<STRING>\\f {
  if(string_too_long()) {return string_length_error();}
  string_length++;
  string_add("\f");
}

<STRING>\\. {
  if(string_too_long()) {return string_length_error();}
  string_length++;
  string_add(&strdup(yytext)[1]);
}

<STRING>. {
  if(string_too_long()) {return string_length_error();}
  string_length++;
  string_add(yytext);
}

\n {curr_lineno++;}
[ \r\t\v\f] {}
. {
    cool_yylval.error_msg = yytext;
    return(ERROR);
}

%%

void string_add(char* str){
  strcat(string_buf, str);
}

int string_length_error() {
  reset_string();
  cool_yylval.error_msg = "The string is too long";
  return ERROR;
}

bool string_too_long() {
  if(string_length + 1 >= MAX_STR_CONST) {
    BEGIN(BROKENSTRING);
    return true;
  }
  return false;
}

void reset_string() {
  string_length = 0;
  string_buf[0] = '\0';
}
