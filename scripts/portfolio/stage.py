#!/usr/bin/env python3
"""Stage/restore a clean native desktop. Keeps preferences and process IDs in /tmp."""
import json
import os
from pathlib import Path
import plistlib
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
STATE = Path('/private/tmp/macpet-portfolio-state.json')
BACKUP = Path('/private/tmp/macpet-dock-backup.plist')

def run(*args):
    return subprocess.run(args, check=True, capture_output=True)

if sys.argv[1] == 'start':
    if STATE.exists():
        raise SystemExit('Restore the previous staging session before starting another.')
    run('defaults', 'export', 'com.apple.dock', str(BACKUP))
    prefs = plistlib.loads(BACKUP.read_bytes())
    apps = ['/Applications/Safari.app', '/System/Applications/Notes.app',
            '/System/Applications/Reminders.app', '/System/Applications/Calendar.app',
            '/System/Applications/Music.app']
    prefs.update({'persistent-apps': [
        {'tile-data': {'file-data': {'_CFURLString': 'file://' + app + '/', '_CFURLStringType': 15}}, 'tile-type': 'file-tile'}
        for app in apps], 'persistent-others': [], 'recent-apps': [], 'show-recents': False,
        'static-only': False, 'autohide': False, 'tilesize': 58, 'magnification': False,
        'orientation': 'bottom'})
    clean = Path('/private/tmp/macpet-dock-clean.plist')
    clean.write_bytes(plistlib.dumps(prefs))
    STATE.write_text(json.dumps({'pids': []}))
    run('defaults', 'import', 'com.apple.dock', str(clean))
    run('killall', 'Dock')
    for path in ['/private/tmp/macpet-portfolio-command', '/private/tmp/macpet-stage-command']:
        Path(path).unlink(missing_ok=True)
    pids = []
    for args in [['/private/tmp/CaptureStage'], [str(ROOT / '.build/out/Products/Release/MacPet'), '--portfolio']]:
        log = open('/private/tmp/macpet-portfolio-process.log', 'ab')
        proc = subprocess.Popen(args, stdout=log, stderr=log, start_new_session=True)
        pids.append(proc.pid)
        STATE.write_text(json.dumps({'pids': pids}))
    print('Native desktop staged; restore with stage.py stop.')
elif sys.argv[1] == 'stop':
    if STATE.exists():
        for pid in json.loads(STATE.read_text())['pids']:
            try: os.kill(pid, signal.SIGTERM)
            except ProcessLookupError: pass
        run('defaults', 'import', 'com.apple.dock', str(BACKUP))
        run('killall', 'Dock')
        STATE.unlink()
        run('/private/tmp/CaptureStage', '--restore')
        run('osascript', '-e', 'tell application "Antigravity IDE" to activate')
        print('Desktop and Dock restored.')
