#!/bin/bash
cd "$(dirname "$0")"
/c/msys64/ucrt64/bin/gcc -c /tmp/test.c \
  -I "SDL3-3.4.2/x86_64-w64-mingw32/include" \
  -o /tmp/test.o
echo "Exit: $?"
