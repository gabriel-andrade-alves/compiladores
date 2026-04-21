all: 	
		clear
		flex lexico.l
		bison -dy sintatico.y
		g++ -o glf y.tab.c -Wno-free-nonheap-object

		./glf < exemplo.lm