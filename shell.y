
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
#define MAXFILENAME 1024

#include <dirent.h> //wildcard expansion directory stuff
#include <fcntl.h> // open() arguments
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h> // strcmp
#include <unistd.h>

#include "command.h"
#include "trace.h"

void yyerror(const char * s);
int yylex();

void expandWildcard(char * prefix, char * suffix) {
	TRACE("prefix: %s, suffix: %s\n", prefix, suffix);
	if (suffix[0] == 0) {
		// suffix is empty, put prefix in argument
		TRACE("adding entry: %s\n", prefix);
		Command::_currentArgCollector->addArg(strdup(prefix));
		//Command::_currentSimpleCommand->insertArgument(strdup(prefix));
		return;
	}

	// obtain the next component in the suffix && advance suffix
	// if the first character is a '/', get the position of the 2nd
	char * s = NULL;
	if (suffix[0] == '/') {
		s = strchr( (char*)(suffix+1), '/');
	} else {
		s = strchr(suffix, '/');
	}
	TRACE("s: %s\n", s);
	char component[MAXFILENAME] = ""; // must initialize this
	if ( s != NULL ) { // copy up to the first "/"
		strncpy(component, suffix, s - suffix);
		TRACE("after copy component: %s, s: %s, suffix: %s\n", component, s, suffix);
		suffix = s + 1;
	} else { // last part of path, copy the whole thing
		strcpy(component, suffix);
		suffix = suffix + strlen(suffix);
		TRACE("after copy suffix: %s\n", suffix);
	}

	// expand the component
	char newPrefix[MAXFILENAME];
 	if ( strchr(component, '*') == NULL && strchr(component, '?') == NULL ) {
		// component has no wildcards
		TRACE("no wildcard detected\n");

		// only do this if prefix is empty
		if ( prefix == NULL || prefix[0] == 0 ) {
			sprintf(newPrefix, "%s", component);
		} else {
			sprintf(newPrefix, "%s/%s", prefix, component);
		}
		expandWildcard(newPrefix, suffix);
		return;
	}

	TRACE("expanding wildcard in %s\n", component);
	// component has wildcards, convert it to regex
	// allocate enough space for regex
	char * reg = (char*)malloc(2*strlen(component)+10);	
	char * a = component;
	char * r = reg;

	*r = '^';  r++;
	while (*a) {
		if ( *a == '*' ) { // * -> .*
			*r = '.';   r++;
			*r = '*';   r++;
		} else if ( *a == '?' ) { // ? -> .*
			*r = '.';   r++;
		} else if ( *a == '.' ) { // . -> \\.
			*r = '\\';	r++;
			*r = '.';   r++;
		} else if ( *a == '/' ) { // / -> ' '  (remove slash)
			// do nothing
		} else {
			*r = *a; 	r++;
		}
		a++;
	}

	*r = '$';  r++; // end of line
	*r = 0;   // null terminator

	// compile regex
	regex_t re;
	if ( regcomp(&re, reg, REG_EXTENDED|REG_NOSUB) != 0 ) {
		perror("regcomp");
		return;
	}
		
	// if prefix is empty list current directory
	char * dir_name;
	//TRACE("Prefix: %s\n", prefix);
	if ( prefix == NULL ) {
		char * dot_char = ".";
		dir_name = dot_char;
	} else {
		dir_name = prefix;
	}
	
	DIR * dir = opendir(dir_name);
	if (dir == NULL) {
		return;
	}

	struct dirent * ent;
	while ( (ent = readdir(dir)) != NULL ) {
		//check if name matches
		if (regexec(&re, ent->d_name, (size_t)0, NULL, 0) == 0) {
			TRACE("prefix: %s, ent->d_name: %s\n", prefix, ent->d_name);
			if (prefix == NULL || prefix[0] == 0) {
				sprintf(newPrefix, "%s", ent->d_name);
			} else {
				sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
			}
			TRACE("expanded wildcard to %s <--- %s, %s\n", newPrefix, suffix, component);
			if (ent->d_name[0] == '.') { // only add things beginning with . if regex also begins with .
				if (component[0] == '.') {
					expandWildcard(newPrefix, suffix);
				}
			} else {
				expandWildcard(newPrefix, suffix);
			}
		}
	}
}
/*
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

	*r = '^';  r++;
	while (*a) {
		if ( *a == '*' ) { // * -> .*
			*r = '.';   r++;
			*r = '*';   r++;
		} else if ( *a == '?' ) { // ? -> .*
			*r = '.';   r++;
		} else if ( *a == '.' ) { // . -> \\.
			*r = '\\';	r++;
			*r = '.';   r++;
		} else {
			*r = *a; 	r++;
		}
		a++;
	}

	*r = '$';  r++; // end of line
	*r = 0;   // null terminator

	// compile regex
	regex_t re;
	if ( regcomp(&re, reg, REG_EXTENDED|REG_NOSUB) != 0 ) {
		perror("regcomp");
		return;
	}


	// list directory and add as arguments the entries that match the regex
	DIR * dir; 
	if ( (dir = opendir(".")) == NULL) {
		perror("opendir");
		return;
	}

	struct dirent * ent;
	int maxEntries = 20;
	int nEntries = 0;
	char ** array = (char**) malloc(maxEntries*sizeof(char*));

	while ( (ent = readdir(dir)) != NULL ) {

		//check if name matches
		if (regexec(&re, ent->d_name, (size_t)0, NULL, 0) == 0) {

			//reallocate if necessary
			if (nEntries == maxEntries) {
				maxEntries *= 2;
				if ( (array = (char**)realloc(array, maxEntries * sizeof(char*))) == NULL) {
					perror("realloc wildcard buffer");
					exit(1);
				}
			}
			//add argument

			if (ent->d_name[0] == '.') {
				if (arg[0] == '.') {
					// add . filename if the regex starts with a . also
					array[nEntries] = strdup(ent->d_name);
					nEntries++;
				} 
			} else {
				array[nEntries] = strdup(ent->d_name);
				nEntries++;
			}
		}
	}

	closedir(dir);
	qsort(array, nEntries, sizeof(const char *), compare);
	// add arguments
	int i;
	for (i = 0; i < nEntries; i++) {
		Command::_currentSimpleCommand->insertArgument(array[i]);
	}
	free(array);
}
*/

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
		//TRACE("   Yacc: Execute command\n");
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
		Command::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
	}
	;

arg_list:
	arg_list argument
	| /* can be empty */
	;

argument:
	WORD {
		TRACE("   Yacc: insert argument \"%s\"\n", $1);
		//expandWildcardsIfNecessary($1);

		expandWildcard(NULL, $1);
		Command::_currentArgCollector->sortArgs();
		int i;
		for (i = 0; i < Command::_currentArgCollector->nArgs; i++) {
			//add the sorted arguments
			Command::_currentSimpleCommand->insertArgument(Command::_currentArgCollector->argArray[i]);
		}
		Command::_currentArgCollector->clear();
	}
	;

command_word:
	WORD {
		TRACE("   Yacc: insert command \"%s\"\n", $1);

	    Command::_currentSimpleCommand = new SimpleCommand();
	    Command::_currentArgCollector = new ArgCollector();

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
