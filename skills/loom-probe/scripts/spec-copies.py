#!/usr/bin/env python3
"""Report helpers copied between spec files.

Specs share no scope, so the same declaration name with the same body in two
files is a copy, not a coincidence. Run from a component root (src/ui-app);
pass a glob to widen it (default *.spec.ts, tracked files only).
"""
import collections
import hashlib
import re
import subprocess
import sys

GLOB = sys.argv[1] if len(sys.argv) > 1 else '*.spec.ts'
DECL = re.compile(r'^(?:export )?(?:async )?(?:function|class|const|interface|type) ([A-Za-z_]\w*)')
CLOSE = re.compile(r'^[}\)\]];?$')
MIN_LINES = 4

files = subprocess.run(['git', 'ls-files', GLOB], capture_output=True, text=True, check=True).stdout.split()
groups = collections.defaultdict(list)

for path in files:
    lines = open(path, encoding='utf-8').read().split('\n')
    i = 0
    while i < len(lines):
        found = DECL.match(lines[i])
        if not found:
            i += 1
            continue
        end = i + 1
        while end < len(lines) and not CLOSE.match(lines[end]):
            end += 1
        body = lines[i:end + 1]
        if len(body) >= MIN_LINES:
            digest = hashlib.md5(re.sub(r'\s+', ' ', ' '.join(body)).encode()).hexdigest()
            groups[(found.group(1), digest)].append((f'{path}:{i + 1}', len(body)))
        i = end + 1

copies = [(name, sites) for (name, _), sites in groups.items() if len(sites) > 1]
for name, sites in sorted(copies, key=lambda item: -len(item[1])):
    print(f'{name}  x{len(sites)}  ({sites[0][1]} lines each)')
    for site, _ in sites:
        print(f'    {site}')
print(f'\n{len(copies)} copied helpers across {len(files)} spec files', file=sys.stderr)
