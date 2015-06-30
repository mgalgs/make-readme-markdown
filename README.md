## make-readme-markdown.el
*Convert emacs lisp documentation to markdown all day every day*

---

This tool will let you easily convert elisp file headers to markdown text so
long as the file comments and documentation follow standard conventions
(like this file). This is because when you're writing an elisp module, the
module itself should be the canonical source of documentation. But it's not
very user-friendly or good marketing for your project to have an empty
README.md that refers people to your source code, and it's even worse if you
have to maintain two separate files that say the same thing.

### Installation


None

### Usage


The recommended way to use this tool is by putting the following code in
your Makefile and running `make README.md` (You don't even have to clone the
repository!):

    README.md: make-readme-markdown.el YOUR-MODULE.el
    	emacs --script $< <YOUR-MODULE.el >$@ 2>/dev/null

    make-readme-markdown.el:
    	wget -q -O $@ https://raw.github.com/mgalgs/make-readme-markdown/master/make-readme-markdown.el

    .INTERMEDIATE: make-readme-markdown.el

You can also invoke it directly with `emacs --script`:

    $ emacs --script make-readme-markdown.el <elisp-file-to-parse.el 2>/dev/null

All functions and macros in your module with docstrings will be documented
in the output unless they've been marked as private. Convention dictates
that private elisp functions have two hypens, like `cup--noodle`.

### Syntax


In order for this module to do you any good, you should write your
file header comments in a way that make-readme-markdown.el
understands. An attempt has been made to support the most common
file header comment style, so hopefully you shouldn't have to do
anything... The following patterns at the beginning of a line are
special:

* `;;; My Header` :: Creates a header
* `;; o My list item` :: Creates a list item
* `;; * My list item` :: Creates a list item
* `;; - My list item` :: Creates a list item

Everything else is stripped of its leading semicolons and first
space and is passed directly out. Note that you can embed markdown
syntax directly in your comments. This means that you can embed
blocks of code in your comments by leading the line with 4 spaces
(in addition to the first space directly following the last
semicolon). For example:

    (defun strip-comments (line)
      "Stip elisp comments from line"
      (replace-regexp-in-string "^;+ ?" "" line))

Or you can use the triple-backtic+lang approach, like so:

```elisp
(defun strip-comments (line)
  "Stip elisp comments from line"
  (replace-regexp-in-string "^;+ ?" "" line))
```

Remember, if you want to indent code within a list item you need to use
a blank line and 8 spaces. For example:

* I like bananas
* I like pizza

        (eat (make-pizza))

* I like ice cream

We parse everything between `;;; Commentary:` and `;;; Code`. See
make-readme-markdown.el for an example (you might already be
looking at it... whoa, this is really getting meta...).

If there's some more syntax you would like to see supported, submit
an issue at https://github.com/mgalgs/make-readme-markdown/issues

### Function Documentation


#### `(strip-comments LINE)`

Stip elisp comments from line

#### `(trim-string LINE)`

Trim spaces from beginning and end of string

#### `(fix-symbol-references LINE)`

Fix refs like `this` so they don't turn adjacent text into code.

#### `(make-section LINE LEVEL)`

Makes a markdown section using the `#` syntax.

#### `(print-section LINE LEVEL)`

Prints a section made with `make-section`.

#### `(slurp)`

Read all text from stdin as list of lines

#### `(print-formatted-line LINE)`

Prints a line formatted as markdown.

#### `(document-a-function)`

Searches for next defun/macro and print markdown documentation.

-----
<div style="padding-top:15px;color: #d0d0d0;">
Markdown README file generated by
<a href="https://github.com/mgalgs/make-readme-markdown">make-readme-markdown.el</a>
</div>
