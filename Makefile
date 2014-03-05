#Use GNU compiler
cc = gcc -g -Wall
CC = g++ -g -Wall

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

tty-raw-mode.o: tty-raw-mode.c
	gcc -c tty-raw-mode.c

read-line.o: read-line.c
	gcc -c read-line.c

shell: shell.tab.o lex.yy.o command.o
	$(CC) -o shell lex.yy.o shell.tab.o command.o read-line.o tty-raw-mode.o -lfl

clean:
	rm -f lex.yy.c shell.tab.c  shell.tab.h shell *.o

