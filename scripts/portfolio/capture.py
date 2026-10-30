#!/usr/bin/env python3
"""Capture the native app; run stage.py start first and stage.py stop afterward."""
from pathlib import Path
import json
import subprocess
import time

OUT = Path.home() / 'Projects/dhruvie.com/.private/captures/macpet'
OUT.mkdir(parents=True, exist_ok=True)
INPUT = '/private/tmp/macpet-input'
COMMAND = Path('/private/tmp/macpet-portfolio-command')
STAGE = Path('/private/tmp/macpet-stage-command')
events = []
counter = 100

def command(action):
    global counter
    counter += 1
    COMMAND.write_text(f'{counter} {action}')

def input(*args):
    subprocess.run([INPUT, *map(str, args)], check=True)

def shot(name, rect):
    subprocess.run(['screencapture', '-x', '-R' + ','.join(map(str, rect)), str(OUT / name)], check=True)

command('close')
time.sleep(.3)
command('new')
time.sleep(.3)
command('reset')
STAGE.write_text('100 hide')
input('move', 780, 855)
time.sleep(1.2)
shot('01-mochi-dock.png', (430, 760, 445, 350))

record = subprocess.Popen(['screencapture', '-v', '-C', '-k', '-R64,217,1600,900', '-V44', '/private/tmp/macpet-portfolio-raw.mov'], stdout=subprocess.DEVNULL, stderr=open('/private/tmp/macpet-record.log', 'w'))
start = time.monotonic()

def at(seconds, label, fn):
    delay = start + seconds - time.monotonic()
    if delay > 0: time.sleep(delay)
    events.append({'time': round(time.monotonic()-start, 3), 'event': label})
    fn()

at(2.5, 'Walks along the Dock', lambda: command('walk'))
at(4.0, 'Opens Swift Notes', lambda: STAGE.write_text('101 show'))
at(5.0, 'Hops onto the window', lambda: command('jump'))
at(6.5, 'Sits on the window', lambda: command('sit'))
at(6.9, 'Window screenshot', lambda: shot('02-mochi-window.png', (360,470,850,560)))
# Read the real landing position rather than assuming a particular frame rate.
state = json.loads(Path('/private/tmp/macpet-portfolio-status.json').read_text())
pet_x = round(state['x'])
at(7.5, 'Clicks Mochi to wave', lambda: input('click', pet_x, 660))
at(8.5, 'Reaction screenshot', lambda: shot('05-wave-reaction.png', (pet_x-200,460,450,350)))
at(10.2, 'Opens chat with Control-Option-C', lambda: input('chat'))
at(11.0, 'Moves to the message field', lambda: input('move', 1320,875))
at(11.6, 'Types the question', lambda: input('type', 'Explain closures in Swift'))
at(14.6, 'Sends the question', lambda: input('enter'))
at(19.3, 'Streamed-reply screenshot', lambda: shot('03-chat-streaming.png', (780,217,860,793)))
at(24.4, 'Completed-reply closeup', lambda: shot('07-chat-closeup.png', (1090,225,530,700)))
at(25.5, 'Opens Mochi context menu', lambda: input('right', pet_x,660))
at(26.7, 'Opens Assistant submenu', lambda: input('move',pet_x+130,928))
at(27.8, 'Assistant menu screenshot', lambda: shot('04-assistant-menu.png', (pet_x-110,530,650,500)))
at(28.2, 'Moves to another local model', lambda: input('move',pet_x+350,737))
at(29.3, 'Selects gemma3:4b', lambda: input('click',pet_x+350,737))
at(31.5, 'Closes chat', lambda: input('click',1120,257))
at(32.8, 'Opens pet menu', lambda: input('right',pet_x,660))
at(34.0, 'Chooses Take a Nap', lambda: input('click',pet_x+110,868))
at(35.2, 'Moves cursor aside', lambda: input('move',pet_x+180,610))
at(42.0, 'Final result state', lambda: None)
record.wait(timeout=10)
events.append({'time':round(time.monotonic()-start,3), 'event':'Recording complete'})
Path('/private/tmp/macpet-capture-timeline.json').write_text(json.dumps({'pet_x':pet_x,'events':events},indent=2))
Path('/private/tmp/macpet-capture-result.json').write_text(Path('/private/tmp/macpet-portfolio-status.json').read_text())
# One detail shot uses the app's real Super Size action, rendering the sprite at
# 1.6 times its normal Retina resolution rather than enlarging a captured bitmap.
input('right',pet_x,660)
time.sleep(.6)
input('click',pet_x+100,773)
time.sleep(.85)
shot('06-super-size-closeup.png', (pet_x-180,400,360,350))
input('escape')
print(json.dumps({'pet_x':pet_x,'result':json.loads(Path('/private/tmp/macpet-capture-result.json').read_text()),'files':sorted(p.name for p in OUT.iterdir())}))
