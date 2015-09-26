EMACS = emacs

all: README.md

README.md: make-readme-markdown.el
	$(EMACS) --script $< < $< > $@

test: manage.sh
	./manage.sh

update_clients: manage.sh
	./manage.sh update

.PHONY: README.md
