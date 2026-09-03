#!/usr/bin/env python3
"""Rebuild CC0 court foley. Requires Python, numpy, scipy and ffmpeg.
Usage: python tools/prepare_audio.py /path/to/cache
Public source URLs and licenses are documented in assets/audio/CREDITS.md.
"""
import subprocess
import sys
import urllib.request
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

CACHE = Path(sys.argv[1] if len(sys.argv) > 1 else 'builds/audio-source')
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
RATE = 48000
SOURCES = {
    'volleyball': 'https://cdn.freesound.org/previews/497/497968_10813207-hq.mp3',
    'volleyball2': 'https://cdn.freesound.org/previews/379/379337_7020229-hq.mp3',
    'crowd_ooh': 'https://cdn.freesound.org/previews/324/324890_2104797-hq.mp3',
    'crowd_ah': 'https://cdn.freesound.org/previews/324/324896_2104797-hq.mp3',
    'shoes': 'https://bigsoundbank.com/UPLOAD/bwf-en/0938.wav',
}
DATA = {}
for name, url in SOURCES.items():
    target = CACHE / (name + '.wav')
    if not target.exists():
        raw = CACHE / (name + Path(url).suffix)
        request = urllib.request.Request(url, headers={'User-Agent': 'SIDEOUT asset preparation'})
        with urllib.request.urlopen(request) as response:
            raw.write_bytes(response.read())
        if raw != target:
            subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(raw), '-ac', '1', '-ar', str(RATE), str(target)], check=True)
    rate, samples = wavfile.read(target)
    assert rate == RATE
    samples = samples.astype(np.float64) / 32768
    if samples.ndim > 1:
        samples = samples.mean(axis=1)
    DATA[name] = samples


def cut(source, start, end, highpass=70, lowpass=14000):
    x = DATA[source][int(start * RATE):int(end * RATE)].copy()
    x = sosfilt(butter(2, [highpass, lowpass], btype='bandpass', fs=RATE, output='sos'), x)
    return x


def save(name, x, room=True, peak=0.75, fade=0.012):
    if room:
        # Short, quiet early reflections; preserve the recorded contact transient.
        dry = x.copy()
        x = np.pad(x, (0, int(.19 * RATE)))
        for delay, gain in [(0.027, .14), (.061, .09), (.109, .05), (.173, .025)]:
            offset = int(delay * RATE)
            x[offset:offset + len(dry)] += dry * gain
    x -= x.mean()
    attack = min(int(.002 * RATE), len(x) // 2)
    tail = min(int(fade * RATE), len(x) // 2)
    x[:attack] *= np.linspace(0, 1, attack)
    x[-tail:] *= np.linspace(1, 0, tail)
    x *= peak / max(np.max(np.abs(x)), 1e-8)
    assert np.all(np.isfinite(x)) and np.max(np.abs(x)) < 1
    wavfile.write(OUT / (name + '.wav'), RATE, np.round(x * 32767).astype(np.int16))


for i, (source, start, end) in enumerate([
    ('volleyball', 1.91, 2.22), ('volleyball', 4.12, 4.48), ('volleyball2', 2.855, 3.16)
]):
    save('hit_' + str(i), cut(source, start, end, 90, 14000))
save('touch', cut('volleyball2', 1.295, 1.57, 130, 8500))
save('floor', cut('volleyball2', 3.98, 4.40, 55, 10000))
for i, (start, end) in enumerate([(.20, .48), (.65, .93), (1.68, 1.99), (4.88, 5.18)]):
    save('squeak_' + str(i), cut('shoes', start, end, 350, 13500))
# The shoe recording contains the footfall and friction. Isolate its low body
# for quiet running steps, reserving the full-band squeaks for plants and cuts.
for i, (start, end) in enumerate([(.22, .42), (1.69, 1.90)]):
    save('step_' + str(i), cut('shoes', start, end, 70, 950), peak=.5)
save('land', cut('shoes', 8.66, 8.99, 80, 3000), peak=.7)
save('slide', cut('shoes', 10.50, 11.05, 220, 10500), peak=.6)
# Crossfade a steady vowel segment so holding the toss aim has no abrupt loop.
x = cut('crowd_ooh', 6.5, 8.25, 170, 10500)
n = int(.25 * RATE)
blend = np.linspace(0, 1, n)
x[:n] = x[-n:] * (1 - blend) + x[:n] * blend
x = x[:-n]
x *= .65 / np.max(np.abs(x))
wavfile.write(OUT / 'crowd_swell.wav', RATE, np.round(x * 32767).astype(np.int16))
save('crowd_release', cut('crowd_ah', 6.65, 8.60, 150, 12000), room=False, peak=.65, fade=.25)
print('Prepared', len(list(OUT.glob('*.wav'))), 'recorded audio clips')
