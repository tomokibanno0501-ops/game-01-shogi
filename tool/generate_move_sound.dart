// 駒を置く音（短い「コツッ」という減衰音）を合成してWAVファイルとして書き出す
// 開発用スクリプト。著作権フリーの音源をダウンロードする代わりに、ゼロから
// 音を合成することでライセンス上の懸念を無くしている。
//
// 実行方法: dart run tool/generate_move_sound.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _sampleRate = 44100;
const _durationSeconds = 0.15;
const _fundamentalHz = 900.0;
const _overtoneHz = 1800.0;
const _decayTauSeconds = 0.025;
const _noiseDurationSeconds = 0.006;
const _outputPath = 'assets/sounds/piece_move.wav';

void main() {
  final numSamples = (_sampleRate * _durationSeconds).round();
  final samples = Int16List(numSamples);
  final random = Random(42);

  for (var i = 0; i < numSamples; i++) {
    final t = i / _sampleRate;
    final envelope = exp(-t / _decayTauSeconds);

    var sample = 0.6 * sin(2 * pi * _fundamentalHz * t) +
        0.25 * sin(2 * pi * _overtoneHz * t);

    if (t < _noiseDurationSeconds) {
      final noiseEnvelope = 1 - (t / _noiseDurationSeconds);
      sample += (random.nextDouble() * 2 - 1) * 0.5 * noiseEnvelope;
    }

    sample *= envelope;
    final clamped = sample.clamp(-1.0, 1.0);
    samples[i] = (clamped * 32767).round();
  }

  final bytes = _buildWavBytes(samples, _sampleRate);
  final file = File(_outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln('Wrote ${file.path} (${bytes.length} bytes)');
}

Uint8List _buildWavBytes(Int16List samples, int sampleRate) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = samples.length * 2;

  final result = BytesBuilder();

  void writeString(String s) => result.add(s.codeUnits);
  void writeUint32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    result.add(b.buffer.asUint8List());
  }

  void writeUint16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    result.add(b.buffer.asUint8List());
  }

  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(channels);
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);
  writeString('data');
  writeUint32(dataSize);

  final sampleBytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    sampleBytes.setInt16(i * 2, samples[i], Endian.little);
  }
  result.add(sampleBytes.buffer.asUint8List());

  return result.toBytes();
}
