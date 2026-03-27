from pathlib import Path

p = Path('src/main.lisp')
text = p.read_text(encoding='utf-8')
lines = text.splitlines()

start = 666
end = 713

balance = 0
in_string = False
for ln in range(1, start):
    line = lines[ln-1]
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
                balance += 1
            elif ch == ')':
                balance -= 1
        i += 1

print(f'Balance before line {start}:', balance)
for ln in range(start, end+1):
    line = lines[ln-1]
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
                balance += 1
            elif ch == ')':
                balance -= 1
        i += 1
    print(f'line {ln:4}: balance {balance:3} | {line}')

print(f'Balance at end of region (line {end}):', balance)
