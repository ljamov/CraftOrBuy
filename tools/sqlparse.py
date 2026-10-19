"""Tiny parser for the CREATE TABLE / INSERT statements of an SQL dump."""
import re
def columns(sql):
    m = re.search(r'CREATE TABLE `\w+` \((.*?)\n\)', sql, re.S)
    return re.findall(r'^\s*`(\w+)`', m.group(1), re.M)
def rows(sql):
    for stmt in re.finditer(r'INSERT INTO `\w+` VALUES\s*(.*?);\n', sql, re.S):
        s = stmt.group(1); i = 0; n = len(s)
        while i < n:
            if s[i] != '(':
                i += 1; continue
            i += 1; vals = []; cur = ''; 
            while True:
                c = s[i]
                if c == "'":
                    i += 1; buf = []
                    while True:
                        c = s[i]
                        if c == '\\': buf.append(s[i+1]); i += 2; continue
                        if c == "'":
                            if i+1 < n and s[i+1] == "'": buf.append("'"); i += 2; continue
                            i += 1; break
                        buf.append(c); i += 1
                    cur = ''.join(buf); quoted = True
                elif c == ',':
                    vals.append(cur); cur = ''; i += 1
                elif c == ')':
                    vals.append(cur); i += 1; break
                else:
                    cur += c; i += 1
            yield vals
