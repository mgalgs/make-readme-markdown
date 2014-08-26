EMACS = emacs

all: README.md test

README.md: make-readme-markdown.el
	$(EMACS) --script $< < $< > $@

test: test.sh
	./test.sh
