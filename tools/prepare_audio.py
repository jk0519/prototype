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
    'game': 'https://cdn.freesound.org/previews/324/324402_1512122-hq.mp3',
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


def natural_contact(name, center, duration=.38, peak=.82):
    """Keep the real gym transient and room tail with only cleanup and gain."""
    pre = .045
    start = int((center - pre) * RATE)
    x = DATA['game'][start:start + int(duration * RATE)].copy()
    x = high(x - x.mean(), 70)
    x *= peak / max(np.max(np.abs(x)), 1e-9)
    a, f = int(.008 * RATE), int(.055 * RATE)
    x[:a] *= np.linspace(0, 1, a)
    x[-f:] *= np.linspace(1, 0, f)
    wavfile.write(OUT / (name + '.wav'), RATE, np.int16(np.clip(x, -.98, .98) * 32767))


# Separate contacts from one CC0 recording of a real indoor volleyball game.
# The short clips retain the actual ball skin, hand slap, gym reflection and
# nearby court texture. They are not synthesized or layered into a fake thud.
for name, center, duration, peak in [
    ('spike_hit', 251.004, .43, .92),
    ('spike_hit_1', 251.615, .43, .90),
    ('spike_hit_2', 254.983, .43, .92),
    ('serve_hit', 63.188, .44, .90),
    ('serve_hit_1', 71.822, .44, .92),
    ('block_hit', 84.288, .32, .82),
    ('block_hit_1', 85.072, .32, .82),
    ('receive_hit', 207.854, .30, .66),
    ('receive_hit_1', 208.500, .30, .64),
    ('set_hit', 209.189, .24, .52),
    ('set_hit_1', 210.629, .24, .50),
    ('floor_hit', 175.627, .38, .78),
    ('land', 146.096, .30, .48),
]:
    natural_contact(name, center, duration, peak)
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

# A quiet real-gym bed restores the room around isolated contacts. Runtime gain
# remains low so positioning, timing and the ball stay clear.
ambience = band(DATA['game'][int(40.2 * RATE):int(43.8 * RATE)], 90, 10500)
n = int(.45 * RATE)
blend = np.linspace(0, 1, n)
ambience[:n] = ambience[-n:] * (1 - blend) + ambience[:n] * blend
ambience = ambience[:-n]
ambience *= .52 / max(np.max(np.abs(ambience)), 1e-9)
wavfile.write(OUT / 'court_ambience.wav', RATE, np.int16(ambience * 32767))

for obsolete in ['hit_0', 'hit_1', 'hit_2', 'touch', 'floor', 'step_0', 'step_1']:
    (OUT / (obsolete + '.wav')).unlink(missing_ok=True)
print('Prepared', len(list(OUT.glob('*.wav'))), 'recorded audio clips')
