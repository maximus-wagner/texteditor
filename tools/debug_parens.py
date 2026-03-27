from pathlib import Path
p = Path('src/main.lisp')
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
                print(f'Line {ln}:{i+1} - end-string')
            else:
                escaped = False
        else:
            if ch == '"':
                if i >= 2 and line[i-2] == '#' and line[i-1] == '\\':
                    pass
                else:
                    in_string = True
                    escaped = False
                    print(f'Line {ln}:{i+1} - start-string')
            elif ch == ';':
                break
            elif ch == '(':
                stack.append((ln, i+1))
                print(f'Line {ln}:{i+1} - push (  depth={len(stack)}')
            elif ch == ')':
                if stack:
                    popped = stack.pop()
                    print(f'Line {ln}:{i+1} - pop )  depth={len(stack)}')
                else:
                    print(f'Line {ln}:{i+1} - unmatched )')
        i += 1

print('\nFinal stack (unmatched opens):')
for ln, col in stack:
    print(f'  ( at line {ln}, col {col}')
print(f'Total unmatched opens: {len(stack)}')
if stack:
    print('\nContexts for unmatched opens:')
    for ln, col in stack:
        start = max(0, ln-3)
        end = min(len(lines), ln+2)
        print(f'\nContext around line {ln}, col {col}:')
        for i in range(start, end):
            print(f'{i+1:4}: {lines[i]}')
