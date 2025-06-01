SHELL:=/bin/bash

trad: trad.y
	bison trad.y
	cc -o trad trad.tab.c
	rm trad.tab.c

run: trad
	./trad

test: trad
	@cat ./tests/test.txt | ./trad
lines: trad
	@./tests/test.sh

entrega: trad trad.md
	mkdir -p ./entregas/"trad$(ver)"
	cp -T ./trad.y ./entregas/"trad$(ver)"/"trad$(ver).y"
	pandoc --pdf-engine=pdfroff -s ./trad.md -o ./entregas/"trad$(ver)"/"trad$(ver).pdf"

clean:
	rm -f trad.tab.c trad
