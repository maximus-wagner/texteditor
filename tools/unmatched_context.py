from pathlib import Path

p = Path('src/main.lisp')
if not p.exists():
    print('File not found:', p)
    raise SystemExit(2)

text = p.read_text(encoding='utf-8')
lines = text.splitlines()

stack = []
in_string = False

for ln, line in enumerate(lines, start=1):
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
                if i >= 2 and line[i-2] == '#' and line[i-1] == '\\':
                    pass
                else:
                    in_string = True
                    escaped = False
            elif ch == ';':
                break
            elif ch == '(':
                stack.append((ln, i+1))
            elif ch == ')':
                if stack:
                    stack.pop()
                else:
                    # unmatched closing -- ignore for now
                    pass
        i += 1

if not stack:
    print('No unmatched opens found')
    raise SystemExit(0)

print('Unmatched opening parens (total', len(stack), '):')
for ln, col in stack:
    print(f'  ( opened at line {ln}, col {col}')

for ln, col in stack:
    start = max(0, ln-3)
    end = min(len(lines), ln+2)
    print('\nContext around open at line', ln, 'col', col)
    # show the snippet at the column for quick inspection
    snippet = lines[ln-1][max(0, col-1):max(0, col-1)+60]
    print('  Snippet:', snippet)
    for i in range(start, end):
        print(f'{i+1:4}: {lines[i]}')
