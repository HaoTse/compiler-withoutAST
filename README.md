# compiler_withoutAST
NCKU CSIE 2016 compiler final 
* Author: 鄭皓澤(Hao Tse)  
* Tools: flex, bison, qtspim  
* Enviornment: buntu 14.04  
* Commands ("main.c" is the test file)  
```
make  
./final < main.c  
```
* Introduction
After make will produce an "output.asm" file, and load it to qtspim.  
* Functions of each file
  * final.l：lexer.  
  * final.y：parser and code generator.  
  * node.h：symbol table and class of register.  
  * Makefile
  * header.h  
