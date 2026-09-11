#!/usr/bin/env python3
"""Validate App Store metadata blocks in a listing markdown file.

Reads the fenced block that follows each bold field label (the store/listing.md
layout), then checks Apple's limits, the keyword-field rules, and the repo's own
vocabulary gates — derived from the Dart tests, not hand-listed.
"""
import re, sys, pathlib

REPO = pathlib.Path('/Users/dima/supplements')
md = pathlib.Path(sys.argv[1]).read_text()

def block(label):
    m = re.search(r'\*\*' + re.escape(label) + r'\*\*[^\n]*\n+```\n(.*?)\n```', md, re.S)
    return m.group(1) if m else None

fields = {
    'App Name': (block('App Name'), 30),
    'Subtitle': (block('Subtitle'), 30),
    'Promotional text': (block('Promotional text'), 170),
    'Description': (block('Description'), 4000),
    'Keywords': (block('Keywords'), 100),
}

# --- vocabulary gates, derived from the tests -------------------------------
def dart_strings(path, start_marker, end_marker):
    src = (REPO / path).read_text()
    seg = src[src.index(start_marker):]
    seg = seg[:seg.index(end_marker)]
    seg = re.sub(r'//[^\n]*', '', seg)          # strip comments first (house rule)
    return re.findall(r"r?'((?:[^'\\]|\\.)*)'", seg)

legal = dart_strings('test_release/legal_copy_safety_test.dart',
                     'legalForbiddenStems = ', '];')
planner_all = dart_strings('test/l10n/planner_copy_safety_test.dart',
                           'const forbiddenVocabulary', '];')
limit = dart_strings('test/l10n/planner_copy_safety_test.dart',
                     'const limitVocabulary', '];')
stems = []
for s in legal + planner_all + limit:
    if s and s not in stems:
        stems.append(s)

def scan(name, text):
    hits = []
    for stem in stems:
        cap = stem[0].isupper() if stem[0].isalpha() else False
        flags = 0 if cap else re.I
        pat = stem if stem.startswith('\\b') else re.escape(stem) if not any(c in stem for c in '\\') else stem
        for m in re.finditer(pat, text, flags):
            line = text[:m.start()].count('\n') + 1
            hits.append(f'{name}:{line} "{stem}" -> …{text[max(0,m.start()-25):m.end()+25].strip()}…')
    return hits

ok = True
print(f'{"field":18} {"chars":>5} {"bytes":>5} {"max":>4}  status')
for name, (text, limit_n) in fields.items():
    if text is None:
        print(f'{name:18} {"-":>5} {"-":>5} {limit_n:>4}  MISSING'); ok = False; continue
    n, b = len(text), len(text.encode('utf-8'))
    status = 'ok' if n <= limit_n and b <= limit_n else 'OVER LIMIT'
    if status != 'ok': ok = False
    print(f'{name:18} {n:>5} {b:>5} {limit_n:>4}  {status}')

# --- keyword rules -------------------------------------------------------------
kw = fields['Keywords'][0] or ''
title, sub = fields['App Name'][0] or '', fields['Subtitle'][0] or ''
words = kw.split(',')
problems = []
if ', ' in kw or kw != kw.strip(): problems.append('spaces around commas')
if len(set(w.lower() for w in words)) != len(words): problems.append('duplicate keyword')
def toks(s): return set(re.findall(r'[a-z]+', s.lower()))
taken = toks(title) | toks(sub) | {'lifestyle'}
def variants(w):
    w = w.lower(); v = {w}
    if w.endswith('s'): v.add(w[:-1])
    else: v.add(w + 's')
    if w.endswith('ies'): v.add(w[:-3] + 'y')
    return v
for w in words:
    if variants(w) & taken:
        problems.append(f'"{w}" repeats a title/subtitle/category word')
    if any(w2 != w and (w2 in variants(w)) for w2 in words):
        problems.append(f'"{w}" has its plural/singular twin in the field')
for w in words:
    if w.lower() in {'app', 'game', 'free', 'best'}: problems.append(f'generic term "{w}"')
print('\nkeywords:', len(words), 'terms;', 'no problems' if not problems else '; '.join(problems))
if problems: ok = False

# --- vocabulary ------------------------------------------------------------------
all_hits = []
for name, (text, _) in fields.items():
    if text: all_hits += scan(name, text)
print(f'\nvocabulary gate ({len(stems)} stems from the two tests):',
      'clean' if not all_hits else '')
for h in all_hits: print('  ', h)
if all_hits: ok = False
print('\nRESULT:', 'PASS' if ok else 'FAIL')
sys.exit(0 if ok else 1)
