#!/usr/bin/env python3
"""Validates Lunet's String Catalogs.

For every catalog and every language listed in CFBundleLocalizations (App/Info.plist):
  * coverage: every translatable string has a localization whose units are all "translated";
  * format parity: each translation carries the same format specifiers as the English source
    (positional ones in any order, non-positional ones in the same order), the same substitution
    tokens and the same number of line breaks;
  * plurals: plural variations use only the CLDR categories of that language (for integers),
    include every category a whole number can select, and always include "other".

Usage: python3 Lens/Scripts/validate_strings.py [lang ...]   (exit status 1 on any problem)
"""
import json
import plistlib
import re
import sys
from collections import Counter
from pathlib import Path

LENS = Path(__file__).resolve().parent.parent
CATALOGS = [
    'Resources/Localizable.xcstrings',
    'Resources/InfoPlist.xcstrings',
    'Resources/AppShortcuts.xcstrings',
    'Widgets/Localizable.xcstrings',
    'Widgets/InfoPlist.xcstrings',
]

# CLDR cardinal categories: (allowed, required for integer counts).
_ONE_OTHER = ({'one', 'other'}, {'one', 'other'})
_ONE_MANY_OTHER = ({'one', 'many', 'other'}, {'one', 'other'})  # "many" only for 1e6-style numbers
_SLAVIC = ({'one', 'few', 'many', 'other'}, {'one', 'few', 'many'})
_CZ_SK = ({'one', 'few', 'many', 'other'}, {'one', 'few', 'other'})  # "many" is for fractions
_ONE_FEW_OTHER = ({'one', 'few', 'other'}, {'one', 'few', 'other'})
_OTHER = ({'other'}, {'other'})
PLURAL_RULES = {
    **{l: _ONE_OTHER for l in 'en en-GB de nl sv da nb fi el tr hu hi'.split()},
    **{l: _ONE_MANY_OTHER for l in 'es fr it ca pt-BR pt-PT'.split()},
    **{l: _SLAVIC for l in 'ru uk pl'.split()},
    **{l: _CZ_SK for l in 'cs sk'.split()},
    **{l: _ONE_FEW_OTHER for l in 'ro hr'.split()},
    'ar': ({'zero', 'one', 'two', 'few', 'many', 'other'}, {'zero', 'one', 'two', 'few', 'many', 'other'}),
    'he': ({'one', 'two', 'other'}, {'one', 'two', 'other'}),
    **{l: _OTHER for l in 'ja ko zh-Hans zh-Hant th vi id ms'.split()},
}

SPECIFIER = re.compile(
    r'%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(?:lld|llu|ld|lu|d|i|u|f|e|g|@|s|x|X|%)'
    r'|%arg|%#@\w+@|\$\{\w+\}')
INFLECTION = re.compile(r'\^\[(.*?)\]\((?:inflect|morphology)[^)]*\)')


def signature(text):
    text = INFLECTION.sub(r'\1', text)
    positional, ordered = Counter(), []
    for match in SPECIFIER.finditer(text):
        if match.group(1):
            positional[match.group(0)] += 1
        else:
            ordered.append(match.group(0))
    return dict(positional), ordered, text.count('\n')


def units(loc):
    """Yields (label, stringUnit) for every leaf of a localization, and plural category sets."""
    if 'stringUnit' in loc:
        yield '', loc['stringUnit']
    if 'stringSet' in loc:
        yield 'set', {'state': loc['stringSet'].get('state'), 'values': loc['stringSet'].get('values', [])}
    for kind, cases in loc.get('variations', {}).items():
        for case, sub in cases.items():
            for label, unit in units(sub):
                yield f'{kind}.{case}{"." + label if label else ""}', unit
    for name, sub in loc.get('substitutions', {}).items():
        for label, unit in units(sub):
            yield f'%#@{name}@{"." + label if label else ""}', unit


def plural_sets(loc, path=''):
    for kind, cases in loc.get('variations', {}).items():
        if kind == 'plural':
            yield path or 'plural', set(cases)
        for case, sub in cases.items():
            yield from plural_sets(sub, f'{path}{kind}.{case}.')
    for name, sub in loc.get('substitutions', {}).items():
        yield from plural_sets(sub, f'{path}%#@{name}@.')


def source_texts(key, entry, source):
    loc = entry.get('localizations', {}).get(source)
    if not loc:
        return [key]
    texts = [u['value'] for _, u in units(loc) if 'value' in u]
    texts += [v for _, u in units(loc) for v in u.get('values', [])]
    return texts or [key]


def check_catalog(path, languages, problems, coverage):
    data = json.loads(path.read_text())
    source = data.get('sourceLanguage', 'en')
    for key, entry in data['strings'].items():
        if entry.get('shouldTranslate') is False or not key or entry.get('extractionState') == 'stale':
            continue
        src = source_texts(key, entry, source)
        src_sig = signature(src[0])
        src_has_subst = '%#@' in src[0]
        for lang in languages:
            coverage[lang][1] += 1
            loc = entry.get('localizations', {}).get(lang)
            where = f'{path.relative_to(LENS)} [{lang}] "{key}"'
            if not loc:
                problems.append(f'{where}: missing')
                continue
            leaves = list(units(loc))
            if not leaves or any(u.get('state') != 'translated' for _, u in leaves):
                problems.append(f'{where}: not translated')
                continue
            coverage[lang][0] += 1
            for label, unit in leaves:
                values = unit.get('values') if 'values' in unit else [unit['value']]
                for value in values:
                    if label.startswith('%#@'):
                        if '%arg' not in value and src_has_subst:
                            problems.append(f'{where} {label}: missing %arg in "{value}"')
                        continue
                    if signature(value) != src_sig:
                        problems.append(f'{where} {label}: specifiers differ from source: "{value}"')
            allowed, required = PLURAL_RULES.get(lang, (None, None))
            if allowed is None:
                problems.append(f'{where}: no plural rules known for {lang}')
                continue
            for at, cats in plural_sets(loc):
                if not cats <= allowed:
                    problems.append(f'{where} {at}: invalid categories {sorted(cats - allowed)}')
                if not required <= cats:
                    problems.append(f'{where} {at}: missing categories {sorted(required - cats)}')


def main():
    info = plistlib.loads((LENS / 'App/Info.plist').read_bytes())
    languages = sys.argv[1:] or [l for l in info['CFBundleLocalizations'] if l != 'en']
    widget_info = plistlib.loads((LENS / 'Widgets/Info.plist').read_bytes())
    problems = []
    if sorted(widget_info['CFBundleLocalizations']) != sorted(info['CFBundleLocalizations']):
        problems.append('Widgets/Info.plist CFBundleLocalizations differs from App/Info.plist')
    for catalog in CATALOGS:
        coverage = {lang: [0, 0] for lang in languages}
        check_catalog(LENS / catalog, languages, problems, coverage)
        total = next(iter(coverage.values()))[1] if coverage else 0
        worst = min((done * 100 // total if total else 100) for done, total in coverage.values())
        print(f'{catalog}: {total} strings × {len(languages)} languages, lowest coverage {worst}%')
    for problem in problems[:200]:
        print('  ' + problem)
    if problems:
        print(f'FAILED: {len(problems)} problem(s)')
        return 1
    print(f'OK: {len(languages)} languages, 100% coverage, specifiers and plurals valid')
    return 0


if __name__ == '__main__':
    sys.exit(main())
