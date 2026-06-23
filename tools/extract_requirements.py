#!/usr/bin/env python3
import re
import csv
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = root / 'bokses_architecture.sysml'
if not src.exists():
    print('Source file not found:', src)
    raise SystemExit(1)
text = src.read_text(encoding='utf-8')


def find_close_brace(s, start):
    """Return index of closing '}' matching the '{' before start, skipping string literals."""
    i = start
    depth = 1
    while i < len(s):
        c = s[i]
        if c == "'":
            # skip string literal; handle \' escaped single quotes inside
            i += 1
            while i < len(s):
                if s[i] == '\\' and i + 1 < len(s):
                    i += 2
                    continue
                if s[i] == "'":
                    i += 1
                    break
                i += 1
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def extract_text_value(block):
    """Return the concatenated string content of the SysML 'text = ...' field."""
    m = re.search(r'\btext\s*=\s*', block)
    if not m:
        return ''
    i = m.end()
    parts = []
    while i < len(block):
        # skip whitespace and string-concatenation operators
        while i < len(block) and block[i] in " \t\n\r+":
            i += 1
        if i >= len(block) or block[i] != "'":
            break
        i += 1  # skip opening quote
        buf = []
        while i < len(block):
            c = block[i]
            if c == '\\' and i + 1 < len(block):
                nxt = block[i + 1]
                buf.append("'" if nxt == "'" else c)
                i += 2
                continue
            if c == "'":
                i += 1
                break
            buf.append(c)
            i += 1
        parts.append(''.join(buf))
        # peek: if next non-whitespace char is ';', this was the last segment
        j = i
        while j < len(block) and block[j] in " \t\n\r":
            j += 1
        if j < len(block) and block[j] == ';':
            break
    return ' '.join(parts).replace('\n', ' ').strip()


results = []
pos = 0
while True:
    m = re.search(r'requirement\s+def\s+(\w+)\s*\{', text[pos:])
    if not m:
        break
    name = m.group(1)
    start = pos + m.end()
    end = find_close_brace(text, start)
    if end == -1:
        print('Unmatched braces for', name)
        break
    block = text[start:end]
    id_m = re.search(r"id\s*=\s*'([^']*)'", block)
    rid = id_m.group(1) if id_m else ''
    rtext = extract_text_value(block)
    results.append({'name': name, 'id': rid, 'text': rtext})
    pos = end + 1

if not results:
    print('No requirements found.')
    raise SystemExit(1)

# CSV
csv_path = root / 'requirements.csv'
with csv_path.open('w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['req_name', 'id', 'text'])
    for r in results:
        writer.writerow([r['name'], r['id'], r['text']])
print(f'Wrote {csv_path}  ({len(results)} requirements)')

# Excel-compatible HTML
html_path = root / 'requirements.xls'
with html_path.open('w', encoding='utf-8') as f:
    def esc(s):
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('\n', ' ').strip()
    f.write('<html><head><meta charset="utf-8"></head><body>\n')
    f.write('<table border="1"><thead><tr>'
            '<th>Requirement Name</th><th>ID</th><th>Text</th>'
            '</tr></thead>\n<tbody>\n')
    for r in results:
        f.write('<tr><td>{}</td><td>{}</td><td>{}</td></tr>\n'.format(
            esc(r['name']), esc(r['id']), esc(r['text'])))
    f.write('</tbody></table>\n</body></html>')
print(f'Wrote {html_path}')
