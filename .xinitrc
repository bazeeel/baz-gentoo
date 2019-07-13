#!/bin/sh

[ -f "$HOME/.xprofile" ] && . ~/.xprofile

exec i3
#exec dwm
#exec awesome
~/dwm_status &


