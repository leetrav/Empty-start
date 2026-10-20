"""由用户指定CC0原音裁切干声、延展混响；不使用生成式音频模型。

python build_independent_punch.py --ffmpeg /path/to/ffmpeg
依赖numpy；只写项目中的两条派生音频，不改变原始FLAC。
"""
import argparse
import pathlib
import subprocess
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('--ffmpeg', required=True)
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
audio = root / 'assets/audio/sfx/comic'
rate = 44100
raw = subprocess.run([
    args.ffmpeg, '-v', 'error', '-i', str(audio/'sources/hit10.mp3.flac'),
    '-af', 'highpass=f=60,lowpass=f=9000', '-ar', str(rate), '-ac', '1',
    '-f', 'f32le', 'pipe:1'], capture_output=True, check=True).stdout
samples = np.frombuffer(raw, dtype='<f4').copy()
active = np.flatnonzero(np.abs(samples) > np.max(np.abs(samples))*.02)
start = max(0, int(active[0]) - int(.002*rate))
end = min(len(samples), int(active[-1]) + int(.03*rate))
dry = samples[start:end]
dry *= .82 / np.max(np.abs(dry))
fade = min(int(.025*rate), len(dry))
dry[-fade:] *= np.linspace(1., 0., fade)

# 确定性的短房间混响：原录音与衰减反射卷积，尾声不循环重放拳击起音。
length = int(3.0*rate)
channels = []
for seed in [20261020, 20261021]:
    rng = np.random.default_rng(seed)
    t = np.arange(int(2.7*rate))/rate
    impulse = np.convolve(rng.standard_normal(len(t)), np.ones(5)/5., mode='same')
    impulse *= np.exp(-np.log(1000)*t/5.0)
    impulse[:int(.012*rate)] = 0.
    fft_length = 1 << (len(dry)+len(impulse)-1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(dry, fft_length)*np.fft.rfft(impulse, fft_length), fft_length)[:length]
    wet = np.pad(wet, (0, max(0, length-len(wet))))
    window = wet[int(.3*rate):int(.8*rate)]
    wet *= .045/max(float(np.sqrt(np.mean(window**2))), 1e-9)
    channel = wet.copy()
    channel[:len(dry)] += dry
    # 最后仅作资源端防截断；正式退场包络由Godot视觉时钟控制。
    channel[-int(.1*rate):] *= np.linspace(1., 0., int(.1*rate))
    channels.append(channel)
tail = np.stack(channels, axis=1)
tail *= .85/max(.85, float(np.max(np.abs(tail))))

def encode(name, data, count):
    subprocess.run([
        args.ffmpeg, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(rate),
        '-ac', str(count), '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', '6',
        str(audio/name)], input=np.asarray(data, dtype='<f4').tobytes(), check=True)

encode('punch_hit.ogg', dry, 1)
encode('punch_tail.ogg', tail, 2)
print(f'hit10: trimmed {start/rate:.4f}s; dry={len(dry)/rate:.3f}s; tail=3.000s')
