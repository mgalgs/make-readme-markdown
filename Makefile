EMACS = emacs

all: README.md

README.md: make-readme-markdown.el
	$(EMACS) --script $< < $< > $@

test: test.sh
	./test.sh

update_clients: test.sh
	./test.sh update

.PHONY: README.md
