EMACS = emacs

all: README.md

README.md: make-readme-markdown.el
	$(EMACS) --script $< < $< > $@
