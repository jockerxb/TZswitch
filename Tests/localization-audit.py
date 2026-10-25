#!/usr/bin/env python3
"""Reject display copy that bypasses the exhaustive bilingual AppText table."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
# Comments and strings are tokenized together so examples in comments do not
# become UI copy. Brands, UTC and numeric/interpolation-only strings are data.
tokens = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"')
ui_argument = re.compile(r'(?:\b(?:Text|Label|Button|Toggle|TextField)|\.(?:help|accessibilityLabel))\s*\(\s*$|\bwithTitle\s*:\s*$')
brands = {'TZswitch', 'GitHub', 'UTC'}
errors = []
for path in (root / 'Sources').glob('*.swift'):
    source = path.read_text()
    if path.name == 'AppLanguage.swift':
        continue
    for token in tokens.finditer(source):
        if not token.group().startswith('"'):
            continue
        literal = token.group()[1:-1]
        line = source.count('\n', 0, token.start()) + 1
        prefix = source[max(0, token.start()-120):token.start()]
        # City/search data and shell diagnostics live in the core, not UI copy.
        if path.name != 'TimezoneCore.swift' and re.search(r'[\u3400-\u9fff]', literal):
            errors.append(f'{path.name}:{line}: move display copy into AppText')
        elif ui_argument.search(prefix):
            static = re.sub(r'\\\([^)]*\)', '', literal)
            if static not in brands and re.search(r'[A-Za-z\u3400-\u9fff]', static):
                errors.append(f'{path.name}:{line}: use language.text(AppText) for display copy')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('PASS UI copy uses the shared bilingual language layer')
