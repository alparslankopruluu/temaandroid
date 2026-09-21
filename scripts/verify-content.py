#!/usr/bin/env python3
import json
import re
from pathlib import Path
root=Path(__file__).resolve().parent.parent
catalog=json.loads((root/'App/Resources/catalog.json').read_text())
assert catalog['version']==1
assert len(catalog['themes'])>=16
assert len({theme['id'] for theme in catalog['themes']})==len(catalog['themes'])
programmatic_artwork={'pixel-reef','pixel-forest'}
artwork_files=0
for theme in catalog['themes']:
    if theme['artwork'] in programmatic_artwork:
        assert theme.get('appearance')=='pixel'
        assert theme.get('interaction') in {'fish','nature'}
        continue
    folder=root/'App/Resources/Assets.xcassets'/f"{theme['artwork']}.imageset"
    manifest=json.loads((folder/'Contents.json').read_text())
    assert (folder/manifest['images'][0]['filename']).is_file(),theme['id']
    artwork_files+=1
source=json.loads((root/'localization/en.json').read_text())
locales=json.loads((root/'docs/locales.json').read_text())['profiles']['extended']
for locale in locales:
    translated=json.loads((root/f'localization/{locale}.json').read_text())
    assert set(source)==set(translated),locale
    assert all(isinstance(x,str) and x.strip() for x in translated.values()),locale
dynamic_key_pattern=re.compile(r'LocalizedStringKey\("[^"\n]*\\\(')
dynamic_key_violations=[]
for source_root in (root/'App', root/'Widgets'):
    for swift_file in source_root.rglob('*.swift'):
        for line_number,line in enumerate(swift_file.read_text().splitlines(), start=1):
            if dynamic_key_pattern.search(line):
                dynamic_key_violations.append(f'{swift_file.relative_to(root)}:{line_number}')
assert not dynamic_key_violations, f'interpolated LocalizedStringKey literals do not resolve runtime keys: {dynamic_key_violations}'
print(f"PASS: {len(catalog['themes'])} themes ({artwork_files} artwork files, {len(programmatic_artwork)} programmatic); {len(source)} complete keys across {len(locales)} locales; dynamic localization keys safe")
