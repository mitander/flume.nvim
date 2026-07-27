#!/bin/sh
# Deterministic ANSI 0-15 review fixture.
printf '\033[0mANSI 0-15  '
i=0
while [ "$i" -lt 8 ]; do
    printf '\033[48;5;%sm  %02s  \033[0m' "$i" "$i"
    i=$((i + 1))
done
printf '\n           '
while [ "$i" -lt 16 ]; do
    printf '\033[48;5;%sm  %02s  \033[0m' "$i" "$i"
    i=$((i + 1))
done
printf '\n'
