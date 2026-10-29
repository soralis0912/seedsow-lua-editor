#!/usr/bin/env python3
"""Seed the HBLauncher runtime + apps into a Seedsow editor save directory.

Writes slot-INDEPENDENT files:
  sslaunch.lua          the launcher applet (the editor also installs this to slot 4)
  hb.sdk.lua            SDK runtime (loaded by the launcher)
  hb.exploit.lua        ACE bootstrap (loaded by the launcher to enable hb.native)
  hbapps.list           newline list of installed app ids
  hbapp.<id>.json       per-app manifest
  hbapp.<id>.lua        per-app source

Also writes sscode004.lua/ssslot004.ref and sscode016.lua/ssslot016.ref = launcher,
so the running editor loads HBLauncher from slot 4 (side A) or slot 16 (side B)
without a full rebuild. The app store (hbapps.list + hbapp.<id>.*) is shared by
both sides.

Usage: seed.py <save_dir>
"""
import os, sys, json, glob

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # .../HBLauncher


def seed(save_dir):
    def put(name, data):
        with open(os.path.join(save_dir, name), 'w') as f:
            f.write(data)

    launcher = open(os.path.join(ROOT, 'launcher.lua')).read()
    put('sslaunch.lua', launcher)
    put('sscode004.lua', launcher)          # testing: editor opens slot 4 (side A)
    put('ssslot004.ref', 'sscode004.lua\n')
    put('sscode016.lua', launcher)          # testing: editor opens slot 16 (side B)
    put('ssslot016.ref', 'sscode016.lua\n')

    put('hb.sdk.lua', open(os.path.join(ROOT, 'sdk', 'hb.lua')).read())
    put('hb.exploit.lua', open(os.path.join(ROOT, 'sdk', 'exploit.lua')).read())

    ids = []
    for app_dir in sorted(glob.glob(os.path.join(ROOT, 'samples', '*'))):
        manifest_path = os.path.join(app_dir, 'app.json')
        main_path = os.path.join(app_dir, 'main.lua')
        if not (os.path.isfile(manifest_path) and os.path.isfile(main_path)):
            continue
        manifest = json.load(open(manifest_path))
        appid = manifest['id']
        put('hbapp.%s.json' % appid, open(manifest_path).read())
        put('hbapp.%s.lua' % appid, open(main_path).read())
        ids.append(appid)
    put('hbapps.list', '\n'.join(ids) + '\n')
    print('seeded launcher + SDK + %d app(s): %s' % (len(ids), ', '.join(ids)))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: seed.py <save_dir>')
    seed(sys.argv[1])
