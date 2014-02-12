
/*
 * CS-252 Spring 2013
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%token	<string_val> WORD

%token 	NOTOKEN NEWLINE GREAT LESS PIPE AMPERSAND GREATGREAT GREATGREATAMPERSAND GREATAMPERSAND

%union	{
			char   *string_val;
		}

%{

//#define yylex yylex

#include <dirent.h> //wildcard expansion directory stuff
#include <fcntl.h> // open() arguments
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h> // strcmp
#include "command.h"

void yyerror(const char * s);
int yylex();

void expandWildcardsIfNecessary(char* arg) {
	//return if arg does not contain '*' or '?'
 	if ( strchr(arg, '*') == NULL && strchr(arg, '?') == NULL ) {
		Command::_currentSimpleCommand->insertArgument(arg);
		return;
	}

	// convert wildcard to regex:
	// allocate enough space for regex
	char * reg = (char*)malloc(2*strlen(arg)+10);	
	char * a = arg;
	char * r = reg;
	*r = '^';
	r++;
	while (*a) {
		if ( *a == '*' ) { // * -> .*
			*r = '.';
			r++;
			*r = '*';
			r++;
		} else if ( *a == '?' ) { // ? -> .*
			*r = '.';
			r++;
		} else if ( *a == '.' ) { // . -> \\.
			*r = '\\';
			r++;
			*r = '.';
			r++;
		} else {
			*r = *a;
			r++;
		}
		a++;
	}

	*r = '$'; // end of line
	r++;
	*r = 0;   // null terminator

	// compile regex
	regex_t re;
	if ( regcomp(&re, reg, REG_EXTENDED|REG_NOSUB) != 0 ) {
		perror("regcomp");
		return;
	}

	regmatch_t match;

	// list directory and add as arguments the entries that match the regex
	DIR * dir; 
	if ( (dir = opendir(".")) == NULL) {
		perror("opendir");
		return;
	}

	struct dirent * ent;
	while ( (ent = readdir(dir)) != NULL ) {
		if ( !strcmp(ent->d_name, ".") || !strcmp(ent->d_name, "..") ){
			continue;
		}

		//check if name matches
		if (regexec(&re, ent->d_name, (size_t)0, NULL, 0) == 0) {
			//add argument
			Command::_currentSimpleCommand->insertArgument(strdup(ent->d_name));
		}
	}
	closedir(dir);
}

%}

%%

goal:	
	commands
	;

commands: 
	command
	| commands command 
	;

command: simple_command
        ;

simple_command:	
	pipe_list iomodifier_list background_opt NEWLINE {
		//printf("   Yacc: Execute command\n");
		Command::_currentCommand.execute();
	}
	| NEWLINE { 
		Command::_currentCommand.clear();
		Command::_currentCommand.prompt();
	}
	| error NEWLINE { yyerrok; }
	;

pipe_list:
	pipe_list PIPE {
	} command_and_args {
	}
	| command_and_args { 
	}

	;


command_and_args:
	command_word arg_list {
		Command::_currentCommand.
			insertSimpleCommand( Command::_currentSimpleCommand );
	}
	;

arg_list:
	arg_list argument
	| /* can be empty */
	;

argument:
	WORD {
		//printf("   Yacc: insert argument \"%s\"\n", $1);

		expandWildcardsIfNecessary($1);
	}
	;

command_word:
	WORD {
		// handle "exit"
		if (strcmp($1, "exit") == 0) { 
			exit(0);
		}

		//printf("   Yacc: insert command \"%s\"\n", $1);

	    Command::_currentSimpleCommand = new SimpleCommand();
	    Command::_currentSimpleCommand->insertArgument( $1 );
	}
	;

iomodifier_list:
	iomodifier_list iomodifier
	| /* empty */
	;

iomodifier:
	GREATGREAT WORD {
		// if we've already set _outfile, we're doing something ambiguous
		if (Command::_currentCommand._outFile != 0) {
			Command::_currentCommand._ambiguous = 1;
		}

		// append stdout to file
		Command::_currentCommand._openOptions = O_WRONLY | O_CREAT;
		Command::_currentCommand._outFile = $2;
	}
	| GREAT WORD {
		// if we've already set _outfile, we're doing something ambiguous
		if (Command::_currentCommand._outFile != 0) {
			Command::_currentCommand._ambiguous = 1;
		}

		// rewrite the file if it already exists
		Command::_currentCommand._openOptions = O_WRONLY | O_CREAT | O_TRUNC;
		Command::_currentCommand._outFile = $2;
	}
	| GREATGREATAMPERSAND WORD {

		// if we've already set _outfile, we're doing something ambiguous
		if (Command::_currentCommand._outFile != 0) {
			Command::_currentCommand._ambiguous = 1;
		}

		//redirect stdout and stderr to file and append
		Command::_currentCommand._openOptions = O_WRONLY | O_CREAT;
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = $2;

	}
	| GREATAMPERSAND WORD {
		// if we've already set _outfile, we're doing something ambiguous
		if (Command::_currentCommand._outFile != 0) {
			Command::_currentCommand._ambiguous = 1;
		}

		//redirect stdout and stderr to file and truncate
		Command::_currentCommand._openOptions = O_WRONLY | O_CREAT | O_TRUNC;
		Command::_currentCommand._outFile = $2;
		Command::_currentCommand._errFile = $2;

	}
	| LESS WORD {
		// if we've already set _infile, we're doing something ambiguous
		if (Command::_currentCommand._inputFile != 0) {
			Command::_currentCommand._ambiguous = 1;
		}

		Command::_currentCommand._inputFile = $2;
	} 
	;

background_opt:
	AMPERSAND {
		Command::_currentCommand._background = 1;
	}
	| /* empty */
	;

%%

void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

#if 0
main()
{
	yyparse();
}
#endif
