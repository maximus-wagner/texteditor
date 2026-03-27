import sys
from pathlib import Path
p = Path('src/main.lisp')
if not p.exists():
    print('File not found:', p)
    sys.exit(2)

stack = []
unmatched_closing = []
line_no = 0
in_string = False
for line in p.read_text(encoding='utf-8').splitlines():
    line_no += 1
    i = 0
    escaped = False
    while i < len(line):
        ch = line[i]
        if in_string:
            if ch == '\\' and not escaped:
                escaped = True
            elif ch == '"' and not escaped:
                in_string = False
            else:
                escaped = False
        else:
            if ch == '"':
                # Ignore character literal syntax like #\" which includes a double-quote
                if i >= 2 and line[i-2] == '#' and line[i-1] == '\\':
                    # it's a character literal, not a string start
                    pass
                else:
                    in_string = True
                    escaped = False
            elif ch == ';':
                break  # comment to end of line
            elif ch == '(':
                stack.append((line_no, i+1))
            elif ch == ')':
                if stack:
                    stack.pop()
                else:
                    unmatched_closing.append((line_no, i+1))
        i += 1

if in_string:
    print('Unterminated string literal detected (EOF inside string)')

if unmatched_closing:
    print('Unmatched closing parens:')
    for ln, col in unmatched_closing:
        print(f'  ) at line {ln}, col {col}')
else:
    print('No unmatched closing parens')

if stack:
    print('Unmatched opening parens:')
    for ln, col in stack[-20:]:
        print(f'  ( opened at line {ln}, col {col}')
    print(f'(Total unmatched opens: {len(stack)})')
else:
    print('No unmatched opening parens')

# Print surrounding context for first unmatched (open or close)
if unmatched_closing:
    ln, col = unmatched_closing[0]
    lines = p.read_text(encoding='utf-8').splitlines()
    start = max(0, ln-3)
    end = min(len(lines), ln+2)
    print('\nContext:')
    for i in range(start, end):
        print(f'{i+1:4}: {lines[i]}')
elif stack:
    ln, col = stack[-1]
    lines = p.read_text(encoding='utf-8').splitlines()
    start = max(0, ln-3)
    end = min(len(lines), ln+2)
    print('\nContext:')
    for i in range(start, end):
        print(f'{i+1:4}: {lines[i]}')

if unmatched_closing or stack or in_string:
    sys.exit(1)
else:
    print('\nParentheses look balanced (ignoring nested reader macros).')
    sys.exit(0)
