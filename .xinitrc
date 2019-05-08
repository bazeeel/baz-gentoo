#!/bin/sh

[ -f ~/.Xmodmap ] && xmodmap ~/.Xmodmap
[ -f ~/.Xdefaults ] && xrdb -merge ~/.Xdefaults

xset r rate 200 50

exec i3

