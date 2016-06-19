OBJS	= bison.o lex.o

CC		= g++
CFLAGS	= -g3 -std=c++11 -pedantic

final: $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o final -ll

lex.o: lex.c
	$(CC) $(CFLAGS) -c lex.c -o lex.o

lex.c: final.l
	flex final.l
	cp lex.yy.c lex.c

bison.o: bison.c
	$(CC) $(CFLAGS) -c bison.c -o bison.o

bison.c: final.y
	bison -d -v final.y
	cp final.tab.c bison.c
	cmp -s final.tab.h tok.h || cp final.tab.h tok.h

lex.o bison.o: header.h node.h
lex.o: tok.h

clean:
	rm -f *.o *~ lex.c lex.yy.c bison.c tok.h final.tab.c final.tab.h final.output final
