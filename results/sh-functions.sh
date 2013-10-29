#!/bin/sh

# Technical Gunk

#   If not running interactively, we don't need to do anything:

[ -z "$PS1" ] && return

# Editor

#   Wrapper around the standard =emacsclient= executable. This
#   essentially replaces the standard =emacs= command, but this
#   is asynchronous and *doesn't block*:

if [ -d /Applications/Emacs.app ]
then
    alias emacs='/Applications/Emacs.app/Contents/MacOS/bin/emacsclient -n -q -a /Applications/Emacs.app/Contents/MacOS/Emacs'
fi

# Another wrapper around =emacsclient= but this is a blocking
#   approach suitable for being set to the =EDITOR= variable.

if [ -d /Applications/Emacs.app ]
then
    alias e='/Applications/Emacs.app/Contents/MacOS/bin/emacsclient -q -a /Applications/Emacs.app/Contents/MacOS/Emacs'
else
    alias e='emacsclient -q -a emacs'
fi

# Listing Files

#   Using the GNU versions of =ls=, which can be installed by Homebrew
#   or Ports, via: =port install coreutils=

if type gls 2>&1 >/dev/null
then
    alias ls="gls --color"
    alias ll="gls --color -olhA"
else
    alias ls="ls --color"
    alias ll="ls --color -olhA"
fi

# f

#    Wrapper around 'find' that excludes some useless directories, like
#    =classes= and =.git= that ignores case, and does an /or/ around
#    every file name.

#    The first parameter can be a source directory to look for the
#    file(s), or you can do something like 'src/../some-file.txt' to
#    look in the 'src' directory for the files.

function findit {
    START_PATH='.'
    FILES="$*"

    # If we have a phrase src/../nav.handlebars, then we want to look
    # in the 'src' directory for the filename given:
    if echo "$1" | grep '\.\.' >/dev/null
    then
        set $(echo "$1" | sed 's/\/*\.\.\/*/  /');
    fi

    # If the first option is a directory, then look in that path, otherwise,
    # start searching from the current directory.
    if [ -d "$1" -a -n "$2" ]
    then
        START_PATH=$1
        shift
        FILES="$*"
    fi
    
    # Ignore the classes and .git directories, as well as look for every
    # file name given.
    find $START_PATH \
        -not \( -path '*classes*' -or -path '*node_modules*' -or -path '.git*' \) \
        -and -iname $(perl -e 'print join " -o -iname ", @ARGV' $FILES)
}

alias f='noglob findit'

# sf

#    Wrapper around 'find' that returns only a single file. Helpful for calls
#    to an editor when you are pretty sure of the name of the file.

function sf {
    noglob findit *$1* | head -1
}

# ef

#   Combines my 'f' and 'e' functions to easily edit a file in the local
#   directory tree solely by the file name.

function ef {
    e $(f $*)
}

# Dash Documentation

#   I like Dash for pulling up quick technical information, and while I
#   normally use it from Emacs, the following alias is nice from the
#   terminal:

function dash {
  "open dash://$@"
}

# Window Title

#   Can we title the terminal window? Note, don't call this function
#   =title= or bad things will happen.

function xtitle {
    # Old Style? echo -n -e "\033]0;$*\007";;
    case "$1" in
        -t)     shift; echo "\e]1;$*\a";;
        -w)     shift; echo "\e]2;$*\a";;
        -b)     shift; echo "\e]0;$*\a";;
         *)     echo "\e]0;$*\a";;
    esac
}

# Tab

#   Opens a tab in the `Terminal` program and start something running in it.

function xtab() {
  TITLE="$1"
  if [[ $1 = "-t" ]]
  then
      TITLE="$2"
      shift
      shift
  fi
  
  HISTFILE=$HOME/.zsh_histories/$(echo $TITLE | sed 's/ /_/g')

  osascript <<EOF
    tell application "System Events"
      tell process "Terminal" to keystroke "t" using command down
    end
    tell application "Terminal"
      activate
      set custom title of first window to "$TITLE"
      -- do script "echo '\e]1;$TITLE\a'" in window 1
      do script with command "xtitle $TITLE; HISTFILE=$HISTFILE; clear; $*" in window 1
    end tell
EOF
}

# Note Files

#   Created [[file:bin/tagging.org::*Tag%20Listing][tag listing]] and other shell scripts to deal with embedded
#   =org-mode= tags. Each of these take a list of files, so these are
#   some functions that give the files in the /default locations/.

export NOTEPATH="$HOME/Notes"
for FILE in $HOME/Technical $HOME/Personal
do
  if [ -e "$FILE" ]; then
    NOTEPATH="$FILE:$NOTEPATH"
  fi
done

# Based on the =$NOTEPATH= variable, we can get all possible notes.

function all-note-dirs {
  echo $NOTEPATH | sed 's/:/ /g'
}

function all-notes {
  # echo find `all-note-dirs` -name '*.org'
  find -L `all-note-dirs` -name '*.org'
}

# And then we can grep for text in just our notes:

function ngrep {
  egrep -r --max-count=1 --context=3 --include='*.org' --ignore-case \
          --no-messages --word-regexp $* $(all-note-dirs)
}

# Beep

#   I can put this at the end of a long running command and have it
#   tell me when it is complete.

function beep {
    if [ $? -eq 0 ]
    then
        echo $1
        MSG="The background process has completed."
        SAY="I am done."
        if [ -n "$1" ]; then
            MSG="$1 has completed."
            SAY="$1 is done."
        fi
        terminal-notifier -message "$MSG" -title "Process Complete"
        say "$SAY"
    else
        MSG="The background process has failed."
        SAY="I have failed."
        if [ -n "$1" ]; then
            MSG="$1 has failed."
            SAY="$1 has failed."
        fi
        terminal-notifier -message "$MSG" -title "Process Failed"
        say "$SAY"
        /bin/ls /no-file 2>/dev/null   # Make next process know previous failed
    fi
}

# Clip

#   If you want to gather data from the output, but starting with a
#   particular line, and ending with another, use =clip=. For instance:

# #+BEGIN_EXAMPLE
#   nmap -A 192.168.0.1 | clip 'PORT ' 'Service detection performed'
# #+END_EXAMPLE

#   Will show just the "good" stuff from the =nmap= command.

#   Function takes three arguments:

#   1. The text (regular expression, actually) to use to begin printing
#   2. The text to use to end printing (isn't actually
#      printed... should it?)
#   3. Optional text inserted at the beginning of each line.

function clip {
  FIRST=$1
  ENDING=$2
  PADDING=${3:-""}

  perl -ne "\$s=1 if (/$FIRST/); \$s=0 if (/$ENDING/); print \"$PADDING\$_\" if (\$s==1);"
}

# Source Highlighting in Less

#   From [[http://funkworks.blogspot.com/2013/01/syntax-highlighting-in-less-on-osx.html][this blog entry]], comes details how to install the
#   =source-highlight= program on the Mac in order to see various code
#   highlighted in pretty colors.

LESSPIPE=`which src-hilite-lesspipe.sh`
export LESSOPEN="| ${LESSPIPE} %s"
export LESS='-R'

# Whitespace Removers

#    These alias remove trailing whitespace and lines containing
#    nothing by spaces/tabs.

alias pre-commit='git status --porcelain | egrep '\''^[MA]'\'' | cut -d '\'' '\'' -f 3 | xargs perl -pi -e '\''s/\t/    /g; s/[\t ]+$//'\'''
alias pre-add='git status --porcelain | grep "^ M" | cut -d" " -f3 | xargs git add'
alias white='xargs perl -pi -e '\''s/\t/    /g; s/[\t ]+$//'\'''

# Pull

#    Allows me to pull new information from the remote branch, but not
#    loose anything.

function pull {
    git stash
    git pull
    git stash pop
}

# Helper Aliases

#    The following are shortcuts to some git commands that I use all
#    the time. Most people prefix them with a 'g' character to keep
#    them unique.

alias gst='git status'
alias gstatus='git status'
alias gd='git diff'
alias gdc='git diff --cached'
alias gaa='git add --update :/'  # Use full 'git add' if haven't already added it
alias gamend='git commit --amend --no-edit'
alias gstash='git stash'
alias gpop='git stash pop'
alias gshow='git stash show -p stash@{0}'

# Directory Bookmarks

#   [[https://github.com/huyng/bashmarks][This script]] allows us to leave bookmarks to "popular" directories,
#   to jump directly there with a single name.

#   - s bookmarkname - saves the curr dir as bookmarkname
#   - g bookmarkname - jumps to the that bookmark
#   - g b[TAB] - tab completion is available
#   - p bookmarkname - prints the bookmark
#   - p b[TAB] - tab completion is available
#   - d bookmarkname - deletes the bookmark
#   - d [TAB] - tab completion is available
#   - l - list all bookmarks

# The following may already be aliases...
for A in l g d
do
  if [ alias = $(whence -w $A | cut -d: -f2) ]
  then
    unalias $A
  fi
done

if [ -e ~/.bash.d/bashmarks.sh ]
then
    source ~/.bash.d/bashmarks.sh
fi

# Scala Helpers

#    SBT requires more memory than it deserves.

alias bigsbt='java -Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled -XX:MaxPermSize=384M -jar /opt/local/share/sbt/sbt-launch.jar'
