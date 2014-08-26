#!/bin/bash

# Simple regression test to make sure we don't break any users.

users=(
    https://raw.githubusercontent.com/doitian/iy-go-to-char/master/iy-go-to-char.el
    https://raw.githubusercontent.com/coldnew/org-html5slide/master/ox-html5slide.el
    https://raw.githubusercontent.com/coldnew/ac-octave/master/ac-octave.el
    https://raw.githubusercontent.com/coldnew/pangu-spacing/master/pangu-spacing.el
    https://raw.githubusercontent.com/coldnew/linum-relative/master/linum-relative.el
    https://raw.githubusercontent.com/mgalgs/top-o-the-mornin-mode/master/top-o-the-mornin.el
    https://raw.githubusercontent.com/mgalgs/diffview-mode/master/diffview.el
    https://raw.githubusercontent.com/mgalgs/indent-hints-mode/master/indent-hints.el
    https://raw.githubusercontent.com/jart/includeme/master/includeme.el
    https://raw.githubusercontent.com/jart/disaster/master/disaster.el
)

echo "Running regression tests..."

for user in ${users[*]}; do
    curl -s $user > testfile || { echo "Couldn't download $user. Skipping."; continue; }
    emacs --script make-readme-markdown.el < testfile > testfile.md.before 2>/dev/null
    git show origin/master:./make-readme-markdown.el > baseline.el
    emacs --script baseline.el < testfile > testfile.md.after 2>/dev/null
    basename=${user##*/}
    if ! diff testfile.md.before testfile.md.after > $basename.diff; then
        echo "$basename changed. Saved diff to $basename.diff"
    else
        echo "$basename OK"
        rm $basename.diff
    fi
    rm testfile.md.{before,after}
done

rm -f testfile
rm -f baseline.el
