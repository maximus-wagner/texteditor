from pathlib import Path
p = Path('src/main.lisp')
text = p.read_text(encoding='utf-8')
lines = text.splitlines()
start=650
end=740
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
                if start <= ln <= end:
                    print(f'Line {ln}:{i+1} - push (  depth={len(stack)}')
            elif ch == ')':
                if stack:
                    popped = stack.pop()
                    if start <= ln <= end:
                        print(f'Line {ln}:{i+1} - pop )  depth={len(stack)}')
                else:
                    if start <= ln <= end:
                        print(f'Line {ln}:{i+1} - unmatched )')
        i += 1

# print unmatched stack entries that fall in the range
print('\nUnmatched opens in file (top 50):')
for ln, col in stack[-50:]:
    print(f'  ( at line {ln}, col {col}')
print(f'Total unmatched opens: {len(stack)}')
