#!/usr/bin/env python3
"""Encode native screencapture with eased camera moves and emit review frames."""
import json
from pathlib import Path
import subprocess
import sys
sys.path.insert(0, '/private/tmp/macpet-media-tools')
import imageio_ffmpeg

OUT = Path.home() / 'Projects/dhruvie.com/.private/captures/macpet'
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
pet = json.loads(Path('/private/tmp/macpet-capture-timeline.json').read_text())['pet_x']
# Time, absolute source zoom, and the top-left of the camera in desktop points.
# The Dock view includes only standard system apps. All subsequent views end
# above the Dock and begin below the menu bar.
keys = [
    (0,3.6,425,867), (3.9,3.6,425,867), (4.5,3.6,425,585),
    (5.15,1.8,350,500), (6.8,1.8,350,500),
    (7.4,2.88,pet-275,480), (9.25,2.88,pet-275,480),
    (9.95,1.25,384,217), (14.8,1.25,384,217),
    (15.4,2.0,864,235), (18.8,2.0,864,235),
    (21.8,2.0,864,440), (23.4,2.0,864,440),
    (24.0,1.25,384,217), (25.2,1.25,384,217),
    (25.8,1.65,690,480), (26.7,1.65,690,480),
    (27.3,2.64,pet-80,575), (29.9,2.64,pet-80,575),
    (30.5,1.25,384,217), (32.5,1.25,384,217),
    (33.1,1.65,690,480), (34.9,1.65,690,480),
    (35.5,1.8,350,500), (36.1,2.88,pet-275,480),
    (38.1,2.88,pet-275,480), (38.8,1.8,350,500), (41,1.8,350,500)
]

def expression(index):
    expr = str(keys[-1][index])
    for a,b in reversed(list(zip(keys,keys[1:]))):
        av,bv = a[index], b[index]
        value = str(av) if av == bv else f'({av}+({bv-av})*(0.5-0.5*cos(PI*clip((on/30-{a[0]})/{b[0]-a[0]},0,1))))'
        expr = f'if(lt(on/30,{b[0]}),{value},{expr})'
    return expr

z = expression(1)
x = f'max(0,min(iw-iw/zoom,2*({expression(2)}-64)))'
y = f'max(0,min(ih-ih/zoom,2*({expression(3)}-217)))'
vf = f"fps=30,zoompan=z='{z}':x='{x}':y='{y}':d=1:s=1920x1080:fps=30,format=yuv420p"
with open('/private/tmp/macpet-encode.log','w') as log:
    subprocess.run([ffmpeg,'-y','-hide_banner','-i','/private/tmp/macpet-portfolio-raw.mov',
        '-t','41','-vf',vf,'-an','-c:v','libx264','-preset','medium','-crf','17',
        '-r','30','-movflags','+faststart','-map_metadata','-1',
        str(OUT/'08-workflow.mp4')],check=True,stdout=log,stderr=log)
review = Path('/private/tmp/macpet-final-review')
review.mkdir(exist_ok=True)
subprocess.run([ffmpeg,'-y','-v','error','-i',str(OUT/'08-workflow.mp4'),
    '-vf','fps=1',str(review/'second-%02d.png')],check=True)
print('Encoded H.264 MP4 at 1920×1080 / 30 fps; extracted every second for review.')
