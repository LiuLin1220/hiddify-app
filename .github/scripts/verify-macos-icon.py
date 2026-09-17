"""Reject a macOS bundle without a compiled, registered application icon."""

import plistlib
import struct
import sys
from pathlib import Path

app = Path(sys.argv[1])
with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
name = info.get('CFBundleIconFile')
if not isinstance(name, str) or not name or Path(name).name != name:
    raise SystemExit('Missing or invalid CFBundleIconFile')
icon = app / 'Contents/Resources' / (name if name.endswith('.icns') else name + '.icns')
data = icon.read_bytes()
if len(data) < 16 or data[:4] != b'icns' or struct.unpack('>I', data[4:8])[0] != len(data):
    raise SystemExit(f'Invalid compiled ICNS: {icon}')
print(f'Verified app icon: {icon} ({len(data)} bytes)')
