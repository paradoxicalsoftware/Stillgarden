"""Validate packaged audio without playback or network."""
from pathlib import Path
import wave
root = Path(__file__).resolve().parents[1] / 'Resources'
expected = {f'{part}-{season}':60 for part in ['day','night'] for season in ['spring','summer','autumn','winter']}
expected.update({'rain':60,'wind':60,'owl-call':4.393,'thunder-0':12,'thunder-1':16,'thunder-2':20})
for name, seconds in expected.items():
    with wave.open(str(root / (name + '.wav')), 'rb') as audio:
        assert audio.getnchannels() == 2, name
        assert audio.getsampwidth() == 2, name
        assert abs(audio.getnframes()/audio.getframerate() - seconds) < .1, name
assert (root/'garden.png').is_file()
assert (root/'AppIcon.icns').is_file()
print(f'PASS: {len(expected)} audio assets, backdrop and app icon')
