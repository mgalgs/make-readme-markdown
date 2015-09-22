;;; make-readme-markdown.el --- Convert emacs lisp documentation to
;;; markdown all day every day

;; Copyright (C) 2011-2015, Mitchel Humpherys
;; Copyright (C) 2013, Justine Tunney

;; Author: Mitchel Humpherys <mitch.special@gmail.com>
;; Keywords: tools, convenience
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This tool will let you easily convert elisp file headers to markdown text so
;; long as the file comments and documentation follow standard conventions
;; (like this file). This is because when you're writing an elisp module, the
;; module itself should be the canonical source of documentation. But it's not
;; very user-friendly or good marketing for your project to have an empty
;; README.md that refers people to your source code, and it's even worse if you
;; have to maintain two separate files that say the same thing.

;;; Installation:

;; None

;;; Usage:

;; The recommended way to use this tool is by putting the following code in
;; your Makefile and running `make README.md` (You don't even have to clone the
;; repository!):
;;
;;     README.md: make-readme-markdown.el YOUR-MODULE.el
;;     	emacs --script $< <YOUR-MODULE.el >$@ 2>/dev/null
;;
;;     make-readme-markdown.el:
;;     	wget -q -O $@ https://raw.github.com/mgalgs/make-readme-markdown/master/make-readme-markdown.el
;;
;;     .INTERMEDIATE: make-readme-markdown.el
;;
;; You can also invoke it directly with `emacs --script`:
;;
;;     $ emacs --script make-readme-markdown.el <elisp-file-to-parse.el 2>/dev/null
;;
;; All functions and macros in your module with docstrings will be documented
;; in the output unless they've been marked as private. Convention dictates
;; that private elisp functions have two hypens, like `cup--noodle`.

;;; Syntax:

;; In order for this module to do you any good, you should write your
;; file header comments in a way that make-readme-markdown.el
;; understands. An attempt has been made to support the most common
;; file header comment style, so hopefully you shouldn't have to do
;; anything... The following patterns at the beginning of a line are
;; special:
;;
;; o `;;; My Header` :: Creates a header
;; o `;; o My list item` :: Creates a list item
;; o `;; * My list item` :: Creates a list item
;; o `;; - My list item` :: Creates a list item
;;
;; Everything else is stripped of its leading semicolons and first
;; space and is passed directly out. Note that you can embed markdown
;; syntax directly in your comments. This means that you can embed
;; blocks of code in your comments by leading the line with 4 spaces
;; (in addition to the first space directly following the last
;; semicolon). For example:
;;
;;     (defun strip-comments (line)
;;       "Stip elisp comments from line"
;;       (replace-regexp-in-string "^;+ ?" "" line))
;;
;; Or you can use the triple-backtic+lang approach, like so:
;;
;; ```elisp
;; (defun strip-comments (line)
;;   "Stip elisp comments from line"
;;   (replace-regexp-in-string "^;+ ?" "" line))
;; ```
;;
;; Remember, if you want to indent code within a list item you need to use
;; a blank line and 8 spaces. For example:
;;
;; o I like bananas
;; o I like pizza
;;
;;         (eat (make-pizza "pepperoni"))
;;
;; o I like ice cream with pretty syntax highlighting
;;
;; ```elisp
;; (eat (make-ice-cream "vanilla"))
;; ```
;;
;; o I need to go for a run
;;
;; We parse everything between `;;; Commentary:` and `;;; Code`. See
;; make-readme-markdown.el for an example (you might already be
;; looking at it... whoa, this is really getting meta...).
;;
;; If there's some more syntax you would like to see supported, submit
;; an issue at https://github.com/mgalgs/make-readme-markdown/issues

;;; Code:

(setq case-fold-search t)  ;; Ignore case in regexps.
(setq debug-on-error t)

(defun strip-comments (line)
  "Stip elisp comments from line"
  (replace-regexp-in-string "^;+ ?" "" line))

(defun trim-string (line)
  "Trim spaces from beginning and end of string"
  (replace-regexp-in-string " +$" ""
                            (replace-regexp-in-string "^ +" "" line)))

(defun fix-symbol-references (line)
  "Fix refs like `this' so they don't turn adjacent text into code."
  (replace-regexp-in-string "`[^`\t ]+\\('\\)" "`" line nil nil 1))

(defun make-section (line level)
  "Makes a markdown section using the `#' syntax."
  (setq line (replace-regexp-in-string ":?[ \t]*$" "" line))
  (setq line (replace-regexp-in-string " --- " " – " line))
  (format "%s %s" (make-string level ?#) line))

(defun print-section (line level)
  "Prints a section made with `make-section'."
  (princ (make-section line level))
  (princ "\n"))

(defun slurp ()
  "Read all text from stdin as list of lines"
  (let (line lines)
    (condition-case nil
        (while (setq line (read-from-minibuffer ""))
          (setq lines (cons line lines)))
      (error nil))
    (reverse lines)))

(defun print-formatted-line (line)
  "Prints a line formatted as markdown."
  (setq line (fix-symbol-references line))
  (let ((stripped-line (strip-comments line)))
    (cond

     ;; Header line (starts with ";;; ")
     ((string-match "^;;; " line)
      (print-section stripped-line 3))

     ;; list line (starts with " o ")
     ((string-match "^ *o " stripped-line)
      (let ((line (replace-regexp-in-string "^ *\o" "*" stripped-line)))
        (princ line)))

     ;; default (just print it)
     (t
      (princ stripped-line))))

  ;; and a newline
  (princ "\n"))
;; eo print-formatted-line

(defun document-a-function ()
  "Searches for next defun/macro and print markdown documentation."
  (unless (search-forward-regexp
           "^(\\(defun\\|defmacro\\) \\([^ ]+\\) " nil t)
    (throw 'no-more-funcs nil))
  (let ((func (buffer-substring-no-properties
               (match-beginning 2)
               (match-end 2))))
    (when (not (string-match "--" func))
      (move-beginning-of-line 1)
      (let ((start (point)))
        (forward-sexp)
        (eval-region start (point)))
      (let ((text (describe-function
                   (eval (read (format "(function %s)" func))))))
        (if (and (not (string-match "Not documented\\." text))
                 (string-match "(" text))
            (with-temp-buffer
              (insert text)
              (goto-char (match-beginning 0))
              (forward-line)
              (let* ((title-txt (replace-regexp-in-string "\n"
                                                          ""
                                                          (buffer-substring (point)
                                                                            (progn (forward-sexp) (point)))))
                     (rest (buffer-substring (point)
                                             (point-max)))
                     (cleaned-rest (fix-symbol-references rest))
                     (printable (concat (make-section (format "`%s`" title-txt) 4)
                                        cleaned-rest
                                        "\n\n")))
                (princ printable))))))))

(defun mrm--select (lst pred)
  "Filter `lst'.

Keeps items for whom `pred' returns non-nil."
  (delq nil
        (mapcar (lambda (el) (when (funcall pred el) el))
                lst)))

(defvar license-texts '(("MIT" . "The MIT License (MIT).*Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software\\. THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT\\. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE\\.")
                        ("GPLv2" . "This .* is free software.* you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation.* either version 2.*, or (at your option) any later version\\. This .* is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE\\.  See the GNU General Public License for more details\\. You should have received a copy of the GNU General Public License along with this .* if not, write to the Free Software Foundation")
                        ("GPLv3" . "This .* is free software.* you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version\\. This .* is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE\\.  See the GNU General Public License for more details\\. You should have received a copy of the GNU General Public License along with .*  If not, see <http://www\\.gnu\\.org/licenses/>\\.")
                        ("BSD" . "Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:.*Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.*Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution\\. .*Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission\\. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED\\. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE\\.")
                        ("Apachev2" . "Licensed under the Apache License, Version 2\\.0 (the \"License\"); you may not use this file except in compliance with the License. You may obtain a copy of the License at.*http://www\\.apache\\.org/licenses/LICENSE-2\\.0.*Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an \"AS IS\" BASIS,WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied\\. See the License for the specific language governing permissions and limitations under the License\\.")))

(defvar license-badges '(("MIT" . "[![License MIT](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)")
                         ("GPLv2" . "[![License GPLv2](https://img.shields.io/badge/license-GPL_v2-green.svg)](http://www.gnu.org/licenses/gpl-2.0.html)")
                         ("GPLv3" . "[![License GPLv3](https://img.shields.io/badge/license-GPL_v3-green.svg)](http://www.gnu.org/licenses/gpl-3.0.html)")
                         ("BSD" . "[![License BSD](https://img.shields.io/badge/license-BSD-green.svg)](http://opensource.org/licenses/BSD-3-Clause)")
                         ("Apachev2" . "[![License Apache v2](https://img.shields.io/badge/license-Apache_v2-green.svg)](http://www.apache.org/licenses/LICENSE-2.0)")))

(defun squeeze-spaces (txt)
  "Coalesce whitespace."
  (replace-regexp-in-string "[\n[:space:]]+" " " txt))

(defun get-all-comments-single-line (lines)
  (with-temp-buffer
    (insert (mapconcat 'identity
                       (mrm--select lines
                                    (lambda (el) (string-match-p "^[[:space:]]*;" el)))
                       "\n"))
    (let ((comment-start ";")) (uncomment-region 0 (point-max)))
    (downcase (squeeze-spaces (buffer-string)))))

(defun print-badges (lines)
  "Print badges for license, package repo, etc.

Tries to parse a license from the comments, printing a badge for
any license found."
  (let* ((comment-txt (get-all-comments-single-line lines))
         (candidates (mrm--select license-texts (lambda (license)
                                                  (string-match-p (downcase (squeeze-spaces (cdr license)))
                                                                  comment-txt)))))
    (cond
     ((= (length candidates) 0)
      (message "No license found"))
     ((= (length candidates) 1)
      (message "Found license: %s" (caar candidates))
      (princ (format "%s\n" (cdr (assoc (caar candidates) license-badges)))))
     (t
      (message "Multiple licenses found: %s" candidates)))))

(let* ((line nil)
       (title nil)
       (title-lines)
       (lines (slurp))
       (started-output nil)
       (code-mode nil)
       (code (concat "(progn\n" (mapconcat 'identity lines "\n") "\n)")))

  ;; The first line should be like ";;; lol.el --- does stuff".
  (while (if (string-match "^;;;" (car lines))
             (setq title-lines (cons (strip-comments (car lines))
                                     title-lines)
                   lines (cdr lines))))

  (setq title (mapconcat 'identity
                         (reverse title-lines)
                         " "))

  (unless (string= title "")
    (let ((title-parts (split-string title " --- ")))
      (print-section (car title-parts) 2)
      (when (cdr title-parts)
        (princ (format "*%s*\n\n" (cadr title-parts))))
      (princ "---\n")))

  (print-badges lines)

  ;; Process everything else.
  (catch 'break
    (while (setq line (car lines))
      (cond

       ;; Wait until we reach the commentary section.
       ((string-match "^;;; Commentary:?$" line)
        (setq started-output t))

       ;; Once we hit code, attempt to document functions/macros.
       ((string-match "^;;; Code:?$" line)
        (print-section "Function Documentation" 3)
        (princ "\n\n")
        (with-temp-buffer
          (insert code)
          (goto-char 0)
          (lisp-mode)
          (catch 'no-more-funcs
            (while t
              (condition-case exc
                  (document-a-function)
                (error
                 (princ (format "<!-- Error: %s -->\n\n" exc)))))))
        (throw 'break nil))

       ;; Otherwise print out all the documentation.
       (started-output
        (print-formatted-line line)))

      (setq lines (cdr lines)))))

(princ "-----
<div style=\"padding-top:15px;color: #d0d0d0;\">
Markdown README file generated by
<a href=\"https://github.com/mgalgs/make-readme-markdown\">make-readme-markdown.el</a>
</div>\n")

;;; make-readme-markdown.el ends here
