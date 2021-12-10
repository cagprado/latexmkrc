# I'm used to use make, so write a simple makefile that delegates to latexmk
MAKEFLAGS := -Onone
LATEXMK   := latexmk

all:
	@$(LATEXMK)
.PHONY: all

clean:
	@$(LATEXMK) -c
.PHONY: clean

cleanall:
	@$(LATEXMK) -C
.PHONY: clean

%:
	@$(LATEXMK) 'tex/$@'

%.tex:
	@$(LATEXMK) 'tex/$@'
