#!/usr/bin/env python3
"""Catch accidental personal contacts and obvious secrets in release source.
This is a narrow hygiene check, not a complete security scanner.
"""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent.parent
try:
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root, stderr=subprocess.DEVNULL).decode().split('\0')
except subprocess.CalledProcessError:
    paths = [str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and not any(part in {'build','.build','.git','.swiftpm'} for part in p.relative_to(root).parts)]
rules = {
    'personal email': re.compile(r'[A-Za-z0-9_.+%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    'private key': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    'GitHub credential': re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,})'),
}
failures = []
for name in paths:
    path = root / name
    if not name or not path.is_file() or path.suffix in {'.icns', '.png'}:
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        failures.append((name, 'unexpected binary'))
        continue
    for label, pattern in rules.items():
        matches = pattern.findall(text)
        if label == 'personal email':
            matches = [value for value in matches if not value.lower().endswith('.test')]
        if matches:
            failures.append((name, label))
if failures:
    for name, label in failures:
        print(f'{name}: potential {label} (value omitted)')
    raise SystemExit(1)
print('Public source: no personal email, private-key block or obvious GitHub credential detected.')
