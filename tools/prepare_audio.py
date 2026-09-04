#!/usr/bin/env python3
"""Rebuild the bundled CC0 court mix. Requires numpy, scipy and ffmpeg.
Usage: python tools/prepare_audio.py /path/to/cache
"""
import subprocess
import sys
import urllib.request
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfiltfilt

CACHE = Path(sys.argv[1] if len(sys.argv) > 1 else 'builds/audio-source')
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
RATE = 48000
SOURCES = {
    'spike': 'https://cdn.freesound.org/previews/813/813420_17552599-hq.mp3',
    'whoosh': 'https://cdn.freesound.org/previews/719/719637_15601358-hq.mp3',
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


def band(x, low_hz, high_hz):
    return sosfiltfilt(butter(3, [low_hz, high_hz], btype='bandpass', fs=RATE, output='sos'), x)


def low(x, high_hz):
    return sosfiltfilt(butter(3, high_hz, btype='lowpass', fs=RATE, output='sos'), x)


def high(x, low_hz):
    return sosfiltfilt(butter(3, low_hz, btype='highpass', fs=RATE, output='sos'), x)


def finish(name, x, peak=.8, drive=1.35, attack=.006, fade=.018):
    x = x - x.mean()
    x /= max(np.max(np.abs(x)), 1e-9)
    x = np.tanh(x * drive) / np.tanh(drive) * peak
    a, t = int(attack * RATE), int(fade * RATE)
    x[:a] *= np.linspace(0, 1, a)
    x[-t:] *= np.linspace(1, 0, t)
    assert np.all(np.isfinite(x)) and np.max(np.abs(x)) < 1
    wavfile.write(OUT / (name + '.wav'), RATE, np.int16(x * 32767))


# One isolated real volleyball spike at 0.665 s supplies a consistent family of
# ball contacts. Different dry filtering and runtime pitch layers distinguish
# palm strike, block, pass, set, floor, and landing without electronic tones.
x = DATA['spike'][int(.625 * RATE):int(1.22 * RATE)]
finish('spike_hit', band(x, 55, 11500) + low(x, 950) * .42, .88, 1.85, .004)
short = x[:int(.34 * RATE)]
finish('block_hit', low(short, 4200) + high(short, 750) * .24, .88, 1.85, .004, .012)
finish('receive_hit', low(x[:int(.31 * RATE)], 3600), .72, 1.85, .004, .014)
finish('set_hit', low(x[:int(.22 * RATE)], 2600), .62, 1.85, .004, .012)
finish('floor_hit', low(x[:int(.38 * RATE)], 1450), .82, 1.85, .004)
finish('land', low(x[:int(.315 * RATE)], 720), .50, 1.35, .006, .025)
finish('swing_whoosh', band(DATA['whoosh'][:int(.25 * RATE)], 180, 12500), .72, 1.3, .008, .025)

shoe = DATA['shoes']
for i, (start, end) in enumerate([(.20, .48), (.65, .93), (1.68, 1.99), (4.88, 5.18)]):
    finish('squeak_' + str(i), band(shoe[int(start * RATE):int(end * RATE)], 320, 12500), .52)
finish('slide', band(shoe[int(10.50 * RATE):int(11.05 * RATE)], 220, 10500), .48, 1.35, .006, .04)

# A crossfade keeps a held serve-anticipation vowel from clicking at its loop.
crowd = band(DATA['crowd_ooh'][int(6.5 * RATE):int(8.25 * RATE)], 170, 10500)
n = int(.25 * RATE)
blend = np.linspace(0, 1, n)
crowd[:n] = crowd[-n:] * (1 - blend) + crowd[:n] * blend
crowd = crowd[:-n]
crowd *= .65 / max(np.max(np.abs(crowd)), 1e-9)
wavfile.write(OUT / 'crowd_swell.wav', RATE, np.int16(crowd * 32767))
finish('crowd_release', band(DATA['crowd_ah'][int(6.65 * RATE):int(8.60 * RATE)], 150, 12000), .65, 1.0, .006, .25)

for obsolete in ['hit_0', 'hit_1', 'hit_2', 'touch', 'floor', 'step_0', 'step_1']:
    (OUT / (obsolete + '.wav')).unlink(missing_ok=True)
print('Prepared', len(list(OUT.glob('*.wav'))), 'recorded audio clips')
