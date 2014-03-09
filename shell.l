
/*
 *
 * CS-252 Fall 2013
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <regex.h>
#include <string.h>
#include <unistd.h>

#include "read-line.h"
#include "shell.tab.h"
#include "trace.h"

static void yyunput (int c, char *buf_ptr);

void myunputc(int c) {
    unput(c);
}

// code for readline 

int mygetc( FILE * f ) {
	static char *p;
	char ch;

	if ( !isatty(0) ) {
		//stdin is not a tty, call real getc
		return getc(f);
	}

	//stdin is a tty, call our read_line
	if ( p == NULL || *p == 0 ) {
		char * s = read_line();
		p = s;
	}

	ch = *p;
	p++;

	return ch;
}

#undef getc
#define getc(f) mygetc(f)
// end code for readline

%}

%%

\n  	{ return NEWLINE; }
";" 	{ return NEWLINE; }

[ \t] 	{	/* Discard spaces and tabs */ }	

">"		{ return GREAT; }
">>"	{ return GREATGREAT; }
">&"	{ return GREATAMPERSAND; }
">>&"	{ return GREATGREATAMPERSAND; }
"<"		{ return LESS; }
"|" 	{ return PIPE; }
"&" 	{ return AMPERSAND; }

		/*
\`[^\n\`]*\` {
		// handle ` marks for subshell expansion...
		char * subs = strdup(yytext + 1); 	// drop the front tic
		subs[ strlen(subs) - 1] = '\0'; 	// drop the end tick

		// put subs into a buffer

		// redirect stdin of child to read from subs buffer
		// redirect stdout of child to unput into original stdin of parent

		// fork




		pid_t child;

		child = fork();

		if ( child == 0 ) {
			// set stdout to the pipe

			// call main
			main();
		}


		yylval.string_val = strdup(yytext);
		return WORD;
}
		*/

\"[^\n\"]*\" {
		/* handle arguments in quotes by stripping the quotes */

		yytext = (char*)(yytext+1); // drop the front quotes
		yytext[ strlen(yytext) - 1 ] = '\0'; // drop the end quotes

		yylval.string_val = strdup(yytext);
		return WORD;
	}

[^ \t\n][^ \t\n]*  {

		//create regex
		regex_t preg;
		regmatch_t match;
		const char * pattern = "[>|<|\\|]"; // match >, <, or |
		if ( regcomp(&preg, pattern, 0) ) {
			perror ("regex failed to compile");
			exit(1);
		}

		// if we encounter > or |, unput all the characters in reverse order
		if ( !regexec(&preg, yytext, 1, &match, 0) ) {
			TRACE("preg = %d\n", match.rm_so);

			char * temp = (char*)malloc( strlen(yytext) * sizeof(char) );
			temp[0] = '\0'; // add a null terminator
			// copy until our special character
			strncat( temp, yytext, match.rm_so * sizeof(char) ); 
			TRACE("temp: %s\n", temp);

			int i;
			int m = 0;
			// iterate backwards until we reach the regex'd character
			for ( i = strlen(yytext) - 1; i >= match.rm_so; i-- ) {

				TRACE("i: %d, m: %d\n", i, m);

				if ( i == match.rm_so ) {
					char c = yytext[i];
					TRACE("unputting space\n");
					myunputc(' ');
					TRACE("unputting %c\n", c);
					myunputc(c);
				} else {
					TRACE("unputting %c\n", yytext[i]);
					myunputc(yytext[i]);
				}

				m++;
				if (m > 10) { 
					TRACE("exit because lol\n");
					exit(1); 
				} // loooop
			}
			yytext = temp;
		}

		yylval.string_val = strdup(yytext);
		return WORD;
	}

%%

