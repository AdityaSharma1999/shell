
#Use GNU compiler
cc = gcc -g -DDEBUG -Wall
CC = g++ -g -DDEBUG -Wall

LEX=flex
YACC=bison

all: shell 

lex.yy.o: shell.l 
	$(LEX) shell.l
	$(CC) -c lex.yy.c

shell.tab.o: shell.y
	$(YACC) -d shell.y
	$(CC) -c shell.tab.c

command.o: command.cc
	$(CC) -c command.cc

shell: shell.tab.o lex.yy.o command.o
	$(CC) -o shell lex.yy.o shell.tab.o command.o -lfl

cat_grep: cat_grep.cc
	$(CC) -o cat_grep cat_grep.cc

ctrl-c: ctrl-c.cc
	$(CC) -o ctrl-c ctrl-c.cc

regular: regular.cc
	$(CC) -o regular regular.cc 

clean:
	rm -f lex.yy.c shell.tab.c  shell.tab.h shell ctrl-c regular cat_grep *.o

