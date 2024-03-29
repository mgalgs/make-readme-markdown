;;; make-readme-markdown.el --- Convert emacs lisp documentation to
;;; markdown all day every day

;; Copyright (C) 2011-2022, Mitchel Humpherys
;; Copyright (C) 2013, Justine Tunney

;; Author: Mitchel Humpherys <mitch.special@gmail.com>
;; Maintainer: Mitchel Humpherys <mitch.special@gmail.com>
;; Keywords: tools, convenience
;; Version: 1.0
;; URL: https://github.com/mgalgs/make-readme-markdown

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

;; This tool will let you easily convert Elisp file comments to markdown text so
;; long as the file comments and documentation follow standard conventions
;; (like this file). This is because when you're writing an elisp module, the
;; module itself should be the canonical source of documentation. But it's not
;; very user-friendly or good marketing for your project to have an empty
;; README.md that refers people to your source code, and it's even worse if you
;; have to maintain two separate files that say the same thing.

;;; Features:
;;
;; o Smart conversion of standard Elisp comment conventions to equivalent
;;   markdown (section headers, lists, image links, etc)
;; o Public function documentation from docstrings
;; o License badge (auto-detected, see [Badges](#badges))
;; o MELPA and MELPA-Stable badges (auto-detected, see [Badges](#badges))
;; o Travis badge (auto-detected, see [Badges](#badges))
;; o Emacs Icon

;;; Installation:
;;
;; None

;;; Usage:
;;
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
;; All functions, macros, and customizable variables in your module with
;; docstrings will be documented in the output unless they've been marked
;; as private. Convention dictates that private elisp functions have two
;; hypens, like `cup--noodle`.

;;; Badges:
;;
;; A license badge is generated if a license can be detected.  Just include
;; the license in your file's comments like normal, taking care to
;; copy/paste the license from its source verbatim.
;;
;; A MELPA badge is generated if a package is listed on MELPA whose URL
;; matches the URL in your file's pseudo-headers.  Specifically, the URL is
;; taken from that familiar chunk of key-value pairs near the top of your
;; file's pseudo-header comments that usually look something like this:
;;
;;     ;; Author: Mitchel Humpherys <mitch.special@gmail.com>
;;     ;; Keywords: convenience, diff
;;     ;; Version: 1.0
;;     ;; URL: https://github.com/mgalgs/diffview-mode
;;
;; In this case, we would search MELPA for a package whose listed URL
;; matches https://github.com/mgalgs/diffview-mode.  If such a package is
;; found, a MELPA badge is emitted.  The same approach is taken for
;; MELPA-Stable.
;;
;; A Travis badge is generated by querying the Travis API for a project
;; whose `username/repo' key matches the one listed in the URL tag.  So in
;; our example above we would query Travis for a project named
;; `mgalgs/diffview-mode'.  Currently this only works for projects hosted
;; on GitHub.

;;; Syntax:
;;
;; An attempt has been made to support the most common Elisp file comment
;; conventions.  Specifically, following patterns at the beginning of a
;; line are special:
;;
;; o `;;; My Header:` ⇒ Creates a header
;; o `;; o My list item` ⇒ Creates a list item
;; o `;; * My list item` ⇒ Creates a list item
;; o `;; - My list item` ⇒ Creates a list item
;;
;; Everything else is stripped of its leading semicolons and its first
;; space, then is passed directly out.  This means that you can embed
;; markdown syntax directly in your comments.  For example, you can embed
;; blocks of code in your comments by leading the line with 4 spaces (in
;; addition to the first space directly following the last semicolon). For
;; example:
;;
;;     (defun mrm-strip-comments (line)
;;       "Strip elisp comments from line"
;;       (replace-regexp-in-string "^;+ ?" "" line))
;;
;; Or you can use the triple-backtic+lang notation, like so:
;;
;; ```elisp
;; (defun mrm-strip-comments (line)
;;   "Strip elisp comments from line"
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
;; We convert everything between `;;; Commentary:` and `;;; Code` into
;; markdown. See make-readme-markdown.el for a full example (you might
;; already be looking at it... whoa, this is really getting meta...).
;;
;; If there's some more syntax you would like to see supported, submit
;; an issue at https://github.com/mgalgs/make-readme-markdown/issues
;;
;; Many of the functions in this module should probably be "private" (named
;; with a double-hypen ("--") but are left "public" for illustration
;; purposes.

;;; Code:



(require 'json)
(require 'cl)

(setq case-fold-search t)  ;; Ignore case in regexps.
(setq debug-on-error t)

(defvar melpa-archive-json-url "http://melpa.org/archive.json")
(defvar melpa-stable-archive-json-url "http://stable.melpa.org/archive.json")

(defun mrm--get-remote-url-as-string (url)
  (with-current-buffer (url-retrieve-synchronously url t)
    ;; remove http headers:
    (goto-char 0)
    (delete-region 1 (re-search-forward "\r?\n\r?\n"))
    (buffer-string)))

(defun mrm--get-remote-url-as-json (url)
  (json-read-from-string (mrm--get-remote-url-as-string url)))

(defun mrm-strip-comments (line)
  "Strip elisp comments from line"
  (replace-regexp-in-string "^;+ ?" "" line))

(defun mrm-strip-file-variables (line)
  "Strip elisp file variables from the first LINE in a file.
E.g., `-*- lexical-binding: t; -*-'"
  (replace-regexp-in-string " *-\\*-.*-\\*-$" "" line))

(defun mrm-trim-string (line)
  "Trim spaces from beginning and end of string"
  (replace-regexp-in-string " +$" ""
                            (replace-regexp-in-string "^ +" "" line)))

(defun mrm-fix-symbol-references (line)
  "Fix refs like `this' so they don't turn adjacent text into code."
  (replace-regexp-in-string "`[^`\t ]+\\('\\)" "`" line nil nil 1))

(defun mrm-make-section (line level)
  "Makes a markdown section using the `#' syntax."
  (setq line (replace-regexp-in-string ":?[ \t]*$" "" line))
  (setq line (replace-regexp-in-string " --- " " – " line))
  (format "%s %s" (make-string level ?#) line))

(defun mrm-print-section (line level)
  "Prints a section made with `mrm-make-section'."
  (princ (mrm-make-section line level))
  (princ "\n"))

(defun mrm-slurp ()
  "Read all text from stdin as list of lines"
  (let (line lines)
    (condition-case nil
        (while (setq line (read-from-minibuffer ""))
          (setq lines (cons line lines)))
      (error nil))
    (reverse lines)))

(defun mrm-wrap-img-tags (line)
  "Wrap image hyperlinks with img tags."
  (replace-regexp-in-string "[^(]\\(https?://[^[:space:]]+\\(?:png\\|jpg\\|jpeg\\)\\)"
                            "<img src=\"\\1\">"
                            line))

(defun mrm-print-formatted-line (line)
  "Prints a line formatted as markdown."
  (setq line (mrm-wrap-img-tags (mrm-fix-symbol-references line)))
  (let ((stripped-line (mrm-strip-comments line)))
    (cond

     ;; Header line (starts with ";;; ")
     ((string-match "^;;; " line)
      (mrm-print-section stripped-line 3))

     ;; list line (starts with " o ")
     ((string-match "^ *o " stripped-line)
      (let ((line (replace-regexp-in-string "^ *\o" "*" stripped-line)))
        (princ line)))

     ;; default (just print it)
     (t
      (princ stripped-line))))

  ;; and a newline
  (princ "\n"))

(setq doc-function-alist '((defun . mrm-document-a-defun)
                           (defmacro . mrm-document-a-defun)
                           (defcustom . mrm-document-a-defcustom)))

(defun mrm-parse-docs-for-a-thing ()
  "Searches for the next defun/defmacro/defcustom and prints
markdown documentation.

Returns a list of the form `(token token-name title-text docstring)`.
Example return value:
`(\"defun\" \"document-a-defmacro\" \"(document-a-defmacro CODE)\" \"Takes a defmacro form and...\"`"
  (unless (search-forward-regexp "^(\\(defun\\|defmacro\\|defcustom\\) \\([^ ]+\\)" nil t)
    (throw 'no-more-things nil))

  (beginning-of-defun)
  (let* ((beg (point))
         (end (progn
                (forward-sexp)
                (point)))
         (code (car (read-from-string (buffer-substring-no-properties beg end))))
         (token (car code))
         (documenter (mrm-cdr-assoc token doc-function-alist)))
    (when documenter
      (let* ((docresults (funcall documenter code))
             (token-name (symbol-name (nth 1 code)))
             (title-text (car docresults))
             (docstring (cdr docresults)))
        (unless (string-match "--" token-name)
          (list (symbol-name token)
                token-name
                title-text
                docstring))))))

(defun mrm-document-a-defcustom (code)
  "Takes a defcustom form and returns documentation for it as a
string"
  (let* ((title-text (symbol-name (nth 1 code)))
         (docs (mrm-fix-symbol-references (nth 3 code))))
    (cons title-text docs)))

(defun mrm-document-a-defun (code)
  "Takes a defun form and returns documentation for it as a string"
  (let* ((text-quoting-style 'grave)
         (text (describe-function (eval code))))
    (when (and (not (string-match "Not documented\\." text))
               (string-match "(" text))
      (with-temp-buffer
        (insert text)
        (goto-char (match-beginning 0))
        (forward-line)
        (let* ((title-text (replace-regexp-in-string "\n"
                                                     ""
                                                     (buffer-substring (point)
                                                                       (progn (forward-sexp)
                                                                              (point)))))
               (rest (buffer-substring (progn (forward-line 2)
                                              (point))
                                       (progn (goto-char (point-max))
                                              (forward-line -1)
                                              (point))))
               (cleaned-rest (replace-regexp-in-string "[[:space:]]$"
                                                       ""
                                                       (mrm-fix-symbol-references rest))))
          (cons title-text cleaned-rest))))))

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

(defun mrm-squeeze-spaces (txt)
  "Coalesce whitespace."
  (replace-regexp-in-string "[\n[:space:]]+" " " txt))

(defun mrm-get-all-comments-single-line (lines)
  (with-temp-buffer
    (insert (mapconcat (lambda (el) (replace-regexp-in-string "^[[:space:]]*;+" " " el))
                       (mrm--select lines
                                    (lambda (el) (string-match-p "^[[:space:]]*;" el)))
                       "\n"))
    (downcase (mrm-squeeze-spaces (buffer-string)))))

(defun mrm-print-license-badge (lines)
  (let* ((comment-txt (mrm-get-all-comments-single-line lines))
         (candidates (mrm--select license-texts (lambda (license)
                                                  (string-match-p (downcase (mrm-squeeze-spaces (cdr license)))
                                                                  comment-txt)))))
    (cond
     ((= (length candidates) 0)
      (message "No license found"))
     ((= (length candidates) 1)
      (message "Found license: %s" (caar candidates))
      (princ (format "%s\n" (mrm-cdr-assoc (caar candidates) license-badges))))
     (t
      (message "Multiple licenses found: %s" candidates)))))

(defun mrm-get-file-headers (lines)
  (let ((line (car lines))
        headers)
    (while (not (string-match-p "^;;; Commentary:?$" line))
      (when (string-match ";; \\([^[:space:]]+\\): \\(.*\\)"
                          line)
        (setq headers (plist-put headers
                                 (intern (match-string 1 line))
                                 (match-string 2 line))))
      (setq lines (cdr lines))
      (setq line (car lines)))
    headers))

(defun mrm-print-travis-badge (repo-key)
  (let ((j (mrm--get-remote-url-as-json (concat "http://api.travis-ci.org/repos/"
                                                repo-key))))
    (when (mrm-cdr-assoc 'last_build_number j)
      (princ (format "[![Build Status](https://travis-ci.org/%s.svg?branch=master)](https://travis-ci.org/%s)\n"
                     repo-key repo-key)))))

(defun mrm-cdr-assoc (key list)
  (cdr (assoc key list)))

(defun mrm-print-melpa-badge (package-url melpa-json melpa-base-url title)
  (let ((package-json (mrm--select melpa-json (lambda (el)
                                                (string= package-url
                                                         (mrm-cdr-assoc 'url
                                                                        (mrm-cdr-assoc 'props
                                                                                       el))))))
        package-name)
    (when package-json
      (setq package-name (caar package-json))
      (message "Adding badge for %s for %s" melpa-base-url package-name)
      (princ (format "[![%s](%s/packages/%s-badge.svg)](%s/#/%s)\n"
                     title
                     melpa-base-url
                     package-name
                     melpa-base-url
                     package-name)))))

(defun mrm-print-status-badges (lines)
  (let* ((package-url (plist-get file-headers 'URL))
         repo-key repo-parts melpa-json package-json package-name)
    (when (and package-url (string-match-p "^https?://github.com/" package-url))
      (setq repo-parts (split-string package-url "/"))
      (setq repo-key (format "%s/%s"
                             (nth (- (length repo-parts) 2) repo-parts)
                             (nth (- (length repo-parts) 1) repo-parts)))
      (message "Searching for Travis build using GitHub repo-key: %s..." repo-key)
      (mrm-print-travis-badge repo-key)
      (message "Searching for MELPA package using GitHub repo-key: %s..."
               repo-key)
      (mrm-print-melpa-badge package-url
                             (mrm--get-remote-url-as-json melpa-archive-json-url)
                             "http://melpa.org"
                             "MELPA")
      (message "Searching for MELPA stable package using GitHub repo-key: %s..."
               repo-key)
      (mrm-print-melpa-badge package-url
                             (mrm--get-remote-url-as-json melpa-stable-archive-json-url)
                             "http://stable.melpa.org"
                             "MELPA Stable"))))

(defun mrm-print-badges (lines)
  "Print badges for license, package repo, etc.

Tries to parse a license from the comments, printing a badge for
any license found."
  (mrm-print-license-badge lines)
  (mrm-print-status-badges lines))

(defun mrm-print-emacs-icon ()
  "Print emacs icon to generate a fancy README.md."
  (let* ((package-url (plist-get file-headers 'URL))
         (logo-url "<img src=\"https://www.gnu.org/software/emacs/images/emacs.png\" alt=\"Emacs Logo\" width=\"80\" height=\"80\" align=\"right\">"))
    (if package-url
        (progn
          (message "Adding emacs icon with URL: %s" package-url)
          (princ (format "<a href=\"%s\">%s</a>\n"
                         package-url
                         logo-url)))
      (message "Adding emacs icon without URL")
      (princ (format "%s\n"
                     logo-url)))))

(defvar file-headers)

;;; debugging: evaluate this buffer (except for the call to main below),
;;; then instrument this function, and go to a buffer and evaluate:
;;;
;;; (main (split-string (substring-no-properties (buffer-string)) "\n"))

(defun main (lines)
  (let* ((line nil)
         (title nil)
         (title-lines)
         (started-output nil)
         (code-mode nil)
         (code (concat "(progn\n" (mapconcat 'identity lines "\n") "\n)"))
         (docs-alist '(("defun" . nil)
                       ("defmacro" . nil)
                       ("defcustom" . nil))))

    (setq file-headers (mrm-get-file-headers lines))

    ;; Add Emacs icon to README.md first
    (mrm-print-emacs-icon)

    ;; The first line should be like ";;; lol.el --- does stuff".
    (while (if (string-match "^;;;" (car lines))
               (setq title-lines (cons (mrm-strip-comments (car lines))
                                       title-lines)
                     lines (cdr lines))))

    (setq title (mapconcat 'identity
                           (reverse title-lines)
                           " "))

    (unless (string= title "")
      (let ((title-parts (split-string title " --- ")))
        (mrm-print-section (car title-parts) 2)
        (when (cdr title-parts)
          (princ (format "*%s*\n\n" (mrm-strip-file-variables (cadr title-parts)))))
        (princ "---\n")))

    (mrm-print-badges lines)

    ;; Process everything else.
    (catch 'break
      (while (setq line (car lines))
        (cond

         ;; Wait until we reach the commentary section.
         ((string-match "^;;; Commentary:?$" line)
          (setq started-output t))

         ;; Once we hit code, collect documentation for functions/macros.
         ((string-match "^;;; Code:?$" line)
          (princ "\n\n")
          (with-temp-buffer
            (insert code)
            (goto-char 0)
            (lisp-mode)
            (catch 'no-more-things
              (while t
                (condition-case exc
                    (let* ((result (mrm-parse-docs-for-a-thing))
                           (token (nth 0 result))
                           (token-name (nth 1 result))
                           (title-text (nth 2 result))
                           (doc (nth 3 result))
                           (docs-alist-key (if (string= token "defmacro")
                                               "defun"
                                             token)))
                      (when (and token doc)
                        (let* ((doclist (mrm-cdr-assoc docs-alist-key docs-alist))
                               (newdoclist (cons (list token title-text doc) doclist)))
                          (setf (cdr (assoc docs-alist-key docs-alist))
                                newdoclist))))
                  (errorz
                   (princ (format "<!-- Error: %s -->\n\n" exc)))))))
          (throw 'break nil))

         ;; Otherwise print out all the documentation.
         (started-output
          (mrm-print-formatted-line line)))

        (setq lines (cdr lines))))

    ;; Output defcustom docs
    (when (mrm-cdr-assoc "defcustom" docs-alist)
      (mrm-print-section "Customization Documentation" 3)
      (princ "\n")
      (dolist (docspec (reverse (mrm-cdr-assoc "defcustom" docs-alist)))
        (let ((title-text (nth 1 docspec))
              (doc (nth 2 docspec)))
          (princ (concat (mrm-make-section (format "`%s`\n\n" title-text) 4)
                         doc
                         "\n\n")))))

    ;; Output function/macro docs
    (mrm-print-section "Function and Macro Documentation" 3)
    (princ "\n")
    (dolist (docspec (reverse (mrm-cdr-assoc "defun" docs-alist)))
      (let ((token (nth 0 docspec))
            (title-text (nth 1 docspec))
            (doc (nth 2 docspec)))
        (princ (concat (mrm-make-section (format "`%s`%s\n\n"
                                                 title-text
                                                 (if (string= token "defmacro")
                                                     " (macro)"
                                                   ""))
                                         4)
                       doc
                       "\n\n"))))))

(main (mrm-slurp))

(princ "-----
<div style=\"padding-top:15px;color: #d0d0d0;\">
Markdown README file generated by
<a href=\"https://github.com/mgalgs/make-readme-markdown\">make-readme-markdown.el</a>
</div>\n")

;;; make-readme-markdown.el ends here
