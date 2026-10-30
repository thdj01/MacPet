# Native portfolio captures

These scripts record the actual AppKit app with `screencapture`. The opt-in
`--portfolio` launch uses separate preferences, a deterministic streamed Swift
answer, and seeded pet needs. It skips saved conversations, Keychain access,
and all model-server requests. Normal launches retain the existing behavior.

`CaptureStage` supplies a neutral backdrop and a harmless notes window for the
pet to land on. Dock preferences are backed up before staging and restored
afterward. Other applications are hidden and then unhidden.

The choreography is framed for a **1728 × 1117 point, 2× Retina** main display.
Adjust the camera coordinates and still rectangles for a different display.
Screen Recording and Accessibility must be enabled for the terminal or IDE
hosting the session. Avoid interacting with the desktop during capture.

```sh
swift build -c release --disable-sandbox
swiftc scripts/portfolio/CaptureStage.swift -o /private/tmp/CaptureStage
swiftc scripts/portfolio/Input.swift -o /private/tmp/macpet-input
python3 -m pip install --target /private/tmp/macpet-media-tools imageio-ffmpeg pillow

python3 scripts/portfolio/stage.py start
trap 'python3 scripts/portfolio/stage.py stop' EXIT INT TERM
# Let the backdrop and Dock settle before starting the recorder.
sleep 3
python3 scripts/portfolio/capture.py
python3 scripts/portfolio/refine.py
python3 scripts/portfolio/encode.py
python3 scripts/portfolio/stage.py stop
trap - EXIT INT TERM
```

The final assets go to
`~/Projects/dhruvie.com/.private/captures/macpet/`. Raw footage, control files,
preference backups, and review frames stay in `/private/tmp`. The final video
contains 1,230 frames: 41 seconds, 1920 × 1080, H.264, 30 fps, no audio.
Camera moves use cosine easing, and native recording includes the cursor and
click visualization. The closeup uses the real Super Size action to draw the
sprite at a larger native resolution.

Open every final PNG and inspect the extracted `second-*.png` video frames in
chronological order. Check edges, menus, input text, provider labels, bubbles,
and any transient UI. `Review.swift` optionally adds local Vision OCR; it does
not replace visual inspection:

```sh
swiftc scripts/portfolio/Review.swift -o /private/tmp/macpet-review
/private/tmp/macpet-review \
  ~/Projects/dhruvie.com/.private/captures/macpet/*.png \
  /private/tmp/macpet-final-review/second-*.png
```

The model choices in capture mode are fixtures. Selecting a cloud provider is
outside the choreography; do not enter credentials or open a key-entry dialog.
