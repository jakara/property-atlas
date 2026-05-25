#!/usr/bin/env python3
"""Validate all extracted JSON files against their schemas.

Usage: python3 scripts/validate.py
Exit code: 0=all pass, 1=any fail.
"""
import json, sys
from pathlib import Path
from jsonschema import Draft202012Validator, RefResolver

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'
SCH = EXT / 'schemas'

MAPPINGS = {
    'schools.json':                'schools.schema.json',
    'zones.json':                  'zones.schema.json',
    'compounds.json':              'compounds.schema.json',
    'groups.json':                 'groups.schema.json',
    'compound_school_match.json':  'compound_school_match.schema.json',
    'policies.json':               'policies.schema.json',
    'admission_rates.json':        'admission_rates.schema.json',
}

# Load common schema for $ref resolution
common = json.loads((SCH / '_common.schema.json').read_text(encoding='utf-8'))
store = {
    '_common.schema.json': common,
    common['$id']: common,
}

def validate_file(data_file, schema_file):
    schema = json.loads((SCH / schema_file).read_text(encoding='utf-8'))
    data = json.loads((EXT / data_file).read_text(encoding='utf-8'))
    # Build resolver so $ref "_common.schema.json#/$defs/..." works
    resolver = RefResolver(
        base_uri=schema['$id'],
        referrer=schema,
        store={**store, schema['$id']: schema},
    )
    validator = Draft202012Validator(schema, resolver=resolver)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
    return data, errors

total_errors = 0
print(f'Validating {len(MAPPINGS)} files...\n')
for data_file, schema_file in MAPPINGS.items():
    try:
        data, errors = validate_file(data_file, schema_file)
    except FileNotFoundError as e:
        print(f'  ✗ {data_file}: file missing — {e}')
        total_errors += 1
        continue
    except Exception as e:
        print(f'  ✗ {data_file}: schema load error — {e}')
        total_errors += 1
        continue

    n_items = len(data.get('items', []))
    if not errors:
        print(f'  ✓ {data_file:<35} ({n_items} items) — schema OK')
    else:
        total_errors += len(errors)
        print(f'  ✗ {data_file:<35} ({n_items} items) — {len(errors)} errors')
        for e in errors[:5]:
            path = '.'.join(str(p) for p in e.absolute_path)
            msg = e.message[:120]
            print(f'      [{path}] {msg}')
        if len(errors) > 5:
            print(f'      ...({len(errors)-5} more)')

print(f'\nTotal validation errors: {total_errors}')
sys.exit(1 if total_errors else 0)
