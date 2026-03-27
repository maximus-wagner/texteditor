from pathlib import Path

p = Path('src/main.lisp')
if not p.exists():
    print('File not found:', p)
    raise SystemExit(2)

text = p.read_text(encoding='utf-8')
lines = text.splitlines()

balance = 0
max_balance = 0
max_positions = []
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
                # ignore character literal like #\" which includes a quote
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

    if balance > max_balance:
        max_balance = balance
        max_positions = [(ln, balance)]
    elif balance == max_balance:
        max_positions.append((ln, balance))

print('Final balance:', balance)
print('Max balance:', max_balance)
print('Max positions (first 20):')
for ln, b in max_positions[:20]:
    print(f'  line {ln} -> balance {b}')

if max_positions:
    for ln, _ in max_positions[:3]:
        start = max(0, ln-3)
        end = min(len(lines), ln+2)
        print('\nContext around max at line', ln)
        for i in range(start, end):
            print(f'{i+1:4}: {lines[i]}')

print('\nTop 20 lines with highest positive balance:')
balances = []
for ln, b in enumerate([b for (_, b) in [(ln, None) for ln in range(len(lines))]], start=1):
    pass

# Provide a simple per-line balance scan to show last non-zero balances
balance = 0
result = []
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
                balance += 1
            elif ch == ')':
                balance -= 1
        i += 1
    if balance != 0:
        result.append((ln, balance))

for ln, b in result[-30:]:
    print(f'  line {ln:4}: balance {b}')
