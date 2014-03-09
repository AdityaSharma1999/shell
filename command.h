#ifndef command_h
#define command_h

// Command Data Structure
struct SimpleCommand {
	// Available space for arguments currently preallocated
	int _numberOfAvailableArguments;

	// Number of arguments
	int _numberOfArguments;
	char ** _arguments;
	
	SimpleCommand();
	void insertArgument( char * argument );

};

struct ArgCollector {
	//stores and sorts wildcard expanded arguments
	int maxArgs;
	int nArgs;
	char** argArray;

	ArgCollector();

	void addArg( char* arg );
	void sortArgs();
	void clear();

	static ArgCollector _currentCollector;
};

struct Command {
	int _numberOfAvailableSimpleCommands;
	int _numberOfSimpleCommands;
	SimpleCommand ** _simpleCommands;

	char * _outFile;
	char * _inputFile;
	char * _errFile;

	int _background;
	int _openOptions;
	int _ambiguous;

	void prompt();
	void print();
	void execute();
	void clear();
	
	Command();
	void insertSimpleCommand( SimpleCommand * simpleCommand );

	static Command _currentCommand;
	static SimpleCommand *_currentSimpleCommand;
	static ArgCollector *_currentArgCollector;
};

#endif
