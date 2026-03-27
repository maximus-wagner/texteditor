import sys

def check_parens(filename):
    with open(filename, encoding='utf-8') as f:
        s = f.read()
    
    depth = 0
    i = 0
    issues = []
    
    while i < len(s):
        c = s[i]
        
        if c == '"':
            # Skip string literal
            i += 1
            while i < len(s):
                if s[i] == '\\':
                    i += 2  # skip escaped char
                elif s[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            continue
        elif c == ';':
            # Skip comment to end of line
            while i < len(s) and s[i] != '\n':
                i += 1
            continue
        elif c == '#':
            if i + 1 < len(s) and s[i+1] == '|':
                # Block comment
                i += 2
                while i + 1 < len(s):
                    if s[i] == '|' and s[i+1] == '#':
                        i += 2
                        break
                    i += 1
                continue
            elif i + 1 < len(s) and s[i+1] == '\\':
                i += 3  # #\char literal
                continue
            elif i + 1 < len(s) and s[i+1] in ("'", '`', ','):
                i += 2  # quote-like reader macros
                continue
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth < 0:
                line = s[:i].count('\n') + 1
                issues.append(f'Extra ) at line {line}, pos {i}')
                depth = 0
        
        i += 1
    
    if depth > 0:
        issues.append(f'Final depth: {depth} unclosed parens')
    
    if issues:
        for issue in issues:
            print(issue)
    else:
        print('All parens balanced!')

if __name__ == '__main__':
    check_parens(sys.argv[1])
