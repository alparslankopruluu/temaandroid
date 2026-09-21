#!/usr/bin/env python3
"""Compile reviewed locale source JSON into native app/widget string catalogs."""
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
source = json.loads((root/'localization/en.json').read_text())
locales = {}
for path in (root/'localization').glob('*.json'):
    if path.stem.startswith('permissions-'): continue
    value = json.loads(path.read_text())
    if set(value) != set(source): raise SystemExit(f'Key mismatch: {path.name}: missing {set(source)-set(value)}, extra {set(value)-set(source)}')
    locales[path.stem] = value
strings = {key: {'localizations': {locale: {'stringUnit': {'state':'translated','value':values[key]}} for locale,values in locales.items()}} for key in source}
(root/'App/Resources/Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':strings,'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
permissions = {'en': 'Save your wallpaper and Live Photo to your photo library.'}
for path in (root/'localization').glob('permissions-*.json'):
    permissions[path.stem.removeprefix('permissions-')] = json.loads(path.read_text())['NSPhotoLibraryAddUsageDescription']
(root/'App/Resources/InfoPlist.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':{'NSPhotoLibraryAddUsageDescription':{'localizations':{locale:{'stringUnit':{'state':'translated','value':value}} for locale,value in permissions.items()}}},'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
print(f'{len(source)} keys; {len(locales)} locales; {len(permissions)} permission locales')
