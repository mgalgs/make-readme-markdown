#!/bin/bash

# Simple regression test to make sure we don't break any users.

users=(
    https://raw.githubusercontent.com/doitian/iy-go-to-char/master/iy-go-to-char.el
    https://raw.githubusercontent.com/coldnew/org-html5slide/master/ox-html5slide.el
    https://raw.githubusercontent.com/coldnew/ac-octave/master/ac-octave.el
    https://raw.githubusercontent.com/coldnew/pangu-spacing/master/pangu-spacing.el
    https://raw.githubusercontent.com/coldnew/linum-relative/master/linum-relative.el
    https://raw.githubusercontent.com/coldnew/eshell-autojump/master/eshell-autojump.el
    https://raw.githubusercontent.com/coldnew/org-remark/master/ox-remark.el
    https://raw.githubusercontent.com/mgalgs/top-o-the-mornin-mode/master/top-o-the-mornin.el
    https://raw.githubusercontent.com/mgalgs/diffview-mode/master/diffview.el
    https://raw.githubusercontent.com/mgalgs/indent-hints-mode/master/indent-hints.el
    https://raw.githubusercontent.com/mgalgs/jumbobuffer/master/jumbobuffer.el
    https://raw.githubusercontent.com/jart/includeme/master/includeme.el
    https://raw.githubusercontent.com/jart/disaster/master/disaster.el
    https://raw.githubusercontent.com/jart/js2-closure/master/js2-closure.el
    https://raw.githubusercontent.com/emacs-pe/pyimpsort.el/master/pyimpsort.el
    https://raw.githubusercontent.com/emacs-pe/docean.el/master/docean.el
    https://raw.githubusercontent.com/emacs-pe/jist.el/master/jist.el
    https://raw.githubusercontent.com/emacs-pe/vagrant.el/master/vagrant.el
    https://raw.githubusercontent.com/rranelli/auto-package-update.el/master/auto-package-update.el
    https://raw.githubusercontent.com/rranelli/simple-highlight/master/simple-highlight.el
    https://raw.githubusercontent.com/wentasah/meson-mode/master/meson-mode.el
)

regression_test()
{
    echo "Running regression tests..."
    retval=0

    BEFORE=${BEFORE:-origin/master}
    git show ${BEFORE}:./make-readme-markdown.el > baseline.el

    for user in ${users[*]}; do
        curl -s $user > testfile || { echo "Couldn't download $user. Skipping."; continue; }
        emacs --script make-readme-markdown.el < testfile > testfile.md.before 2>/dev/null
        emacs --script baseline.el < testfile > testfile.md.after 2>/dev/null
        basename=${user##*/}
        if ! diff testfile.md.before testfile.md.after > $basename.diff; then
            echo "$basename changed. Saved diff to $basename.diff. Also copying here:"
            cat $basename.diff
            retval=1
        else
            echo "$basename OK"
            rm $basename.diff
        fi
        rm testfile.md.{before,after}
    done

    rm -f testfile
    rm -f baseline.el
    return $retval
}

update_clients()
{
    work=$(mktemp -d)
    echo "Updating all repos in ${work}."
    echo "  [*] means it has changes"
    echo "  [!] means there was an error rebuilding README.md"
    cd $work
    for user in ${users[*]}; do
        repo=$(cut -d/ -f4-5 <<<$user)
        echo -n "Updating ${repo}..."
        git clone https://github.com/$repo &>/dev/null
        (
            cd $(basename $repo)
            [[ $repo =~ ^mgalgs/ ]] || {
                hub fork &>/dev/null
                git fetch mgalgs &>/dev/null
                git checkout mgalgs/master &>/dev/null || echo "Couldn't checkout mgalgs/master..."
            }
            rm README.md
            make README.md &>/dev/null
            ret=$?
            [[ $ret -eq 0 ]] || { echo " [!]"; exit $ret; }
            if git status --porcelain | grep -q README.md; then
                echo " [*]"
                git commit -am 'README.md: Re-generate' >/dev/null
            else
                echo
            fi
        )
    done
}

[[ $1 == "update" ]] && { update_clients; exit $?; }
regression_test
exit $?
