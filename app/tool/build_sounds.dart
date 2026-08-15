// Writes the game's sound effects as WAV files into assets/sounds/.
//
//   dart run tool/build_sounds.dart
//
// Synthesised rather than sourced: no licensing to track, nothing to attribute,
// the repository stays self-contained, and simple tones suit a quiet puzzle
// game better than sampled effects would. Pure Dart, no Flutter.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 22050;

void main() {
  final directory = Directory('assets/sounds')..createSync(recursive: true);

  // The placement ladder: one file per step up a major scale, so each mine
  // placed sounds a note higher than the last. Twelve covers the largest board
  // with room to spare.
  const scale = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19];
  for (var i = 0; i < scale.length; i++) {
    final frequency = 392.0 * math.pow(2, scale[i] / 12); // from G4 upward
    _write(
      '${directory.path}/place_${i.toString().padLeft(2, '0')}.wav',
      _tone(
        frequency: frequency,
        seconds: 0.16,
        harmonics: const [1.0, 0.35, 0.12],
        attack: 0.004,
        decay: 0.15,
        gain: 0.42,
      ),
    );
  }

  // A soft tick for marking a cell clear. Quiet on purpose: it happens
  // constantly, and anything with character would grate within a minute.
  _write(
    '${directory.path}/mark.wav',
    _tone(
      frequency: 1180,
      seconds: 0.05,
      harmonics: const [1.0, 0.2],
      attack: 0.002,
      decay: 0.045,
      gain: 0.16,
    ),
  );

  // Taking something back: the placement note, downward.
  _write(
    '${directory.path}/remove.wav',
    _sweep(from: 520, to: 300, seconds: 0.12, gain: 0.3),
  );

  // A refused placement. Low and buzzy, unmistakably negative.
  _write(
    '${directory.path}/error.wav',
    _tone(
      frequency: 150,
      seconds: 0.22,
      harmonics: const [1.0, 0.6, 0.45, 0.3],
      attack: 0.003,
      decay: 0.2,
      gain: 0.5,
    ),
  );

  // Winning: a major arpeggio, the one moment allowed to be pleased with itself.
  _write('${directory.path}/win.wav', _arpeggio(
    const [523.25, 659.25, 783.99, 1046.50],
    noteSeconds: 0.14,
    gain: 0.4,
  ));

  // A star landing on the win sheet, one pitch per star.
  const starNotes = [783.99, 987.77, 1174.66];
  for (var i = 0; i < starNotes.length; i++) {
    _write(
      '${directory.path}/star_${i + 1}.wav',
      _tone(
        frequency: starNotes[i],
        seconds: 0.3,
        harmonics: const [1.0, 0.5, 0.25],
        attack: 0.003,
        decay: 0.28,
        gain: 0.4,
      ),
    );
  }

  // The board going up: a downward sweep under a burst of noise.
  _write('${directory.path}/boom.wav', _explosion());

  stdout.writeln('Wrote ${directory.listSync().length} files to assets/sounds/');
}

/// A tone with a few harmonics and an exponential decay.
Float64List _tone({
  required double frequency,
  required double seconds,
  required List<double> harmonics,
  required double attack,
  required double decay,
  required double gain,
}) {
  final samples = Float64List((seconds * _sampleRate).round());
  for (var i = 0; i < samples.length; i++) {
    final t = i / _sampleRate;
    var value = 0.0;
    for (var h = 0; h < harmonics.length; h++) {
      value += harmonics[h] * math.sin(2 * math.pi * frequency * (h + 1) * t);
    }
    samples[i] = value * gain * _envelope(t, attack, decay);
  }
  return samples;
}

Float64List _sweep({
  required double from,
  required double to,
  required double seconds,
  required double gain,
}) {
  final samples = Float64List((seconds * _sampleRate).round());
  var phase = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final t = i / _sampleRate;
    final progress = t / seconds;
    final frequency = from + (to - from) * progress;
    phase += 2 * math.pi * frequency / _sampleRate;
    samples[i] = math.sin(phase) * gain * _envelope(t, 0.003, seconds * 0.9);
  }
  return samples;
}

Float64List _arpeggio(
  List<double> notes, {
  required double noteSeconds,
  required double gain,
}) {
  final total = (noteSeconds * notes.length + 0.35) * _sampleRate;
  final samples = Float64List(total.round());
  for (var n = 0; n < notes.length; n++) {
    final start = (n * noteSeconds * _sampleRate).round();
    // Notes ring on rather than cutting off, so the chord builds.
    final voice = _tone(
      frequency: notes[n],
      seconds: 0.45,
      harmonics: const [1.0, 0.4, 0.15],
      attack: 0.004,
      decay: 0.4,
      gain: gain,
    );
    for (var i = 0; i < voice.length && start + i < samples.length; i++) {
      samples[start + i] += voice[i];
    }
  }
  return samples;
}

Float64List _explosion() {
  const seconds = 0.8;
  final samples = Float64List((seconds * _sampleRate).round());
  // Deterministic noise, so rebuilding never changes the file.
  var seed = 12345;
  var phase = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final t = i / _sampleRate;
    final progress = t / seconds;

    seed = (1103515245 * seed + 12345) % 2147483648;
    final noise = (seed / 2147483648) * 2 - 1;

    final frequency = 140 - 100 * progress;
    phase += 2 * math.pi * frequency / _sampleRate;
    final body = math.sin(phase);

    final envelope = math.exp(-3.4 * progress);
    samples[i] = (body * 0.65 + noise * 0.45 * math.exp(-7 * progress)) *
        envelope *
        0.7;
  }
  return samples;
}

double _envelope(double t, double attack, double decay) {
  if (t < attack) return t / attack;
  return math.exp(-(t - attack) / (decay / 4));
}

/// 16-bit mono PCM.
void _write(String path, Float64List samples) {
  final bytes = BytesBuilder();
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    data.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  final pcm = data.buffer.asUint8List();

  void ascii(String text) => bytes.add(text.codeUnits);
  void uint32(int value) =>
      bytes.add((ByteData(4)..setUint32(0, value, Endian.little))
          .buffer
          .asUint8List());
  void uint16(int value) =>
      bytes.add((ByteData(2)..setUint16(0, value, Endian.little))
          .buffer
          .asUint8List());

  ascii('RIFF');
  uint32(36 + pcm.length);
  ascii('WAVE');
  ascii('fmt ');
  uint32(16);
  uint16(1); // PCM
  uint16(1); // mono
  uint32(_sampleRate);
  uint32(_sampleRate * 2); // byte rate
  uint16(2); // block align
  uint16(16); // bits per sample
  ascii('data');
  uint32(pcm.length);
  bytes.add(pcm);

  File(path).writeAsBytesSync(bytes.toBytes());
}
