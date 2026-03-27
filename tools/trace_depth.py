import sys

def trace_depth(filename, start_line, end_line):
    with open(filename, encoding='utf-8') as f:
        s = f.read()
    
    depth = 0
    i = 0
    
    while i < len(s):
        c = s[i]
        line_num = s[:i].count('\n') + 1
        
        if c == '"':
            i += 1
            while i < len(s):
                if s[i] == '\\':
                    i += 2
                elif s[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            continue
        elif c == ';':
            while i < len(s) and s[i] != '\n':
                i += 1
            continue
        elif c == '#':
            if i + 1 < len(s) and s[i+1] == '|':
                i += 2
                while i + 1 < len(s):
                    if s[i] == '|' and s[i+1] == '#':
                        i += 2
                        break
                    i += 1
                continue
            elif i + 1 < len(s) and s[i+1] == '\\':
                i += 3
                continue
        elif c == '(':
            depth += 1
            if start_line <= line_num <= end_line:
                print(f'L{line_num}: + (depth={depth})')
        elif c == ')':
            if start_line <= line_num <= end_line:
                print(f'L{line_num}: - (depth={depth})')
            depth -= 1
            if depth < 0:
                print(f'EXTRA ) at line {line_num}!')
                depth = 0
        
        i += 1
    
    print(f'Final depth: {depth}')

if __name__ == '__main__':
    trace_depth(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
