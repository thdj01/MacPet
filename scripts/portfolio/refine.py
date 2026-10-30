#!/usr/bin/env python3
"""Refine still framing without changing the recorded workflow."""
from pathlib import Path
import subprocess
import time
OUT = Path.home()/'Projects/dhruvie.com/.private/captures/macpet'
def action(s):
    Path('/private/tmp/macpet-portfolio-command').write_text(f'{time.time()} {s}')
def inp(*args): subprocess.run(['/private/tmp/macpet-input',*map(str,args)],check=True)
def shot(name,rect): subprocess.run(['screencapture','-x','-R'+','.join(map(str,rect)),str(OUT/name)],check=True)
action('close'); time.sleep(.2)
action('sit'); time.sleep(.3)
inp('right',946,660)
inp('move',1076,928)
time.sleep(.7)
shot('04-assistant-menu.png',(900,545,600,485))
inp('click',1296,713) # Return to qwen3:8b for the earlier chat scene.
time.sleep(.3)
inp('chat'); time.sleep(.5)
action('new'); time.sleep(.3)
inp('type','Explain closures in Swift')
inp('enter')
time.sleep(6.7)
inp('move',1645,400)
shot('03-chat-streaming.png',(360,217,1280,813))
time.sleep(1.5)
action('close'); time.sleep(.3)
action('wave'); time.sleep(.3)
inp('right',946,660)
time.sleep(.4)
inp('click',1046,773)
time.sleep(.7)
action('wave'); time.sleep(.5)
shot('06-super-size-closeup.png',(766,400,360,350))
inp('move',1645,400)
print('Refined the streaming-chat landscape, model menu, and enlarged wave detail.')
