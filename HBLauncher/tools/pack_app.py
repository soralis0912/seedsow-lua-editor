#!/usr/bin/env python3
"""Package an HBLauncher app folder into the two staged files you send from a PC.

Given an app folder (the same layout as HBLauncher/samples/<id>/: app.json +
main.lua), this writes `hbstage.json` and `hbstage.lua` and prints the exact
steps to install it over the editor's existing PC file transfer -- no FTP, no
network server, no on-console change. See ../docs/INSTALL_FROM_PC.md.

Usage: pack_app.py <app_dir> [out_dir]   (out_dir defaults to the current dir)
"""
import json
import os
import re
import sys

ID_RE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9-]*$')   # matches launcher.lua's id check


def pack(app_dir, out_dir='.'):
    manifest_path = os.path.join(app_dir, 'app.json')
    main_path = os.path.join(app_dir, 'main.lua')
    if not os.path.isfile(manifest_path):
        raise SystemExit('No app.json in ' + app_dir)
    if not os.path.isfile(main_path):
        raise SystemExit('No main.lua in ' + app_dir)

    manifest_text = open(manifest_path, encoding='utf-8').read()
    try:
        manifest = json.loads(manifest_text)
    except ValueError as err:
        raise SystemExit('app.json is not valid JSON: ' + str(err))
    appid = manifest.get('id', '')
    if not ID_RE.match(appid):
        raise SystemExit('app.json "id" missing or invalid (need [A-Za-z0-9][A-Za-z0-9-]*): ' + repr(appid))
    if manifest.get('format') != 'hblauncher.seedsow-app':
        print('warning: "format" is not "hblauncher.seedsow-app"', file=sys.stderr)

    source = open(main_path, encoding='utf-8').read()

    os.makedirs(out_dir, exist_ok=True)
    stage_json = os.path.join(out_dir, 'hbstage.json')
    stage_lua = os.path.join(out_dir, 'hbstage.lua')
    # Send the manifest text as-is: the launcher parses it with plain patterns.
    open(stage_json, 'w', encoding='utf-8').write(manifest_text)
    open(stage_lua, 'w', encoding='utf-8').write(source)

    print('packed "%s" (%s)' % (manifest.get('name', appid), appid))
    print('  ' + stage_json)
    print('  ' + stage_lua)
    print()
    print('To install from the PC companion (pc/), per ../docs/INSTALL_FROM_PC.md:')
    print('  1. Send tab -> mode "Raw file" -> filename "hbstage.json" -> send that file.')
    print('  2. Same, filename "hbstage.lua".')
    print('  3. On the console open HBLauncher (slot 4 side A / slot 16 side B) and press Y.')
    return stage_json, stage_lua


if __name__ == '__main__':
    if not 2 <= len(sys.argv) <= 3:
        raise SystemExit('usage: pack_app.py <app_dir> [out_dir]')
    pack(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else '.')
