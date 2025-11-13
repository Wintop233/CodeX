import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Represents the voice that should be used for the keyboard style instrument.
///
enum InstrumentVoice {
  piano,
  electric,
  custom,
}

/// A reusable audio sample that can either come from bundled assets or
/// recordings created by the user.
class SoundSample {
  SoundSample({
    required this.id,
    required this.label,
    this.assetPath,
    this.file,
    this.recordedAt,
    this.bytes,
  });

  final String id;
  final String label;
  final String? assetPath;
  final File? file;
  final DateTime? recordedAt;
  final Uint8List? bytes;

  bool get isAsset => assetPath != null;
  bool get isRecording => file != null;
  bool get isGenerated => bytes != null;
}

/// Keeps track of the various sound clips the musician can work with and
/// exposes helper methods for widgets that want to react to changes.
class SoundLibrary extends ChangeNotifier {
  SoundLibrary() {
    for (var i = 0; i < 9; i++) {
      _padRecordings[i] = null;
    }
  }

  InstrumentVoice _selectedVoice = InstrumentVoice.piano;
  File? _keyboardRecording;
  final Map<int, File?> _padRecordings = <int, File?>{};
  final Uint8List _pianoPreset =
      _WaveformFactory.generatePianoSample(frequency: 261.63);
  final Uint8List _electricPreset =
      _WaveformFactory.generateElectricPianoSample(frequency: 261.63);

  InstrumentVoice get selectedVoice => _selectedVoice;

  UnmodifiableMapView<int, File?> get padRecordings =>
      UnmodifiableMapView<int, File?>(_padRecordings);

  File? get keyboardRecording => _keyboardRecording;

  void setVoice(InstrumentVoice voice) {
    if (_selectedVoice == voice) {
      return;
    }
    _selectedVoice = voice;
    notifyListeners();
  }

  void setKeyboardRecording(File? file) {
    _keyboardRecording = file;
    if (file != null) {
      _selectedVoice = InstrumentVoice.custom;
    }
    notifyListeners();
  }

  void setPadRecording(int padIndex, File? file) {
    if (!_padRecordings.containsKey(padIndex)) {
      throw ArgumentError('Pad index $padIndex is not supported');
    }
    _padRecordings[padIndex] = file;
    notifyListeners();
  }

  SoundSample keyboardPresetSample() {
    switch (_selectedVoice) {
      case InstrumentVoice.electric:
        return SoundSample(
          id: 'keyboard',
          label: 'Electric Piano',
          bytes: _electricPreset,
        );
      case InstrumentVoice.custom:
        final file = _keyboardRecording;
        return SoundSample(
          id: 'keyboard',
          label: 'Custom',
          file: file,
          recordedAt:
              file != null && file.existsSync() ? file.lastModifiedSync() : null,
        );
      case InstrumentVoice.piano:
      default:
        return SoundSample(
          id: 'keyboard',
          label: 'Grand Piano',
          bytes: _pianoPreset,
        );
    }
  }

  SoundSample padSample(int padIndex) {
    final file = _padRecordings[padIndex];
    return SoundSample(
      id: 'pad_$padIndex',
      label: 'Pad ${padIndex + 1}',
      file: file,
      recordedAt: file != null && file.existsSync() ? file.lastModifiedSync() : null,
    );
  }
}

class _WaveformFactory {
  static const double _sampleRate = 44100;

  static Uint8List generatePianoSample({required double frequency}) {
    return _generateWaveform(
      frequency: frequency,
      durationSeconds: 1.8,
      overallGain: 0.7,
      partials: const [
        _Partial(multiplier: 1, amplitude: 0.9, decaySeconds: 1.4),
        _Partial(multiplier: 2, amplitude: 0.4, decaySeconds: 1.0),
        _Partial(multiplier: 3, amplitude: 0.25, decaySeconds: 0.8),
      ],
    );
  }

  static Uint8List generateElectricPianoSample({required double frequency}) {
    return _generateWaveform(
      frequency: frequency,
      durationSeconds: 1.4,
      overallGain: 0.65,
      partials: const [
        _Partial(multiplier: 1, amplitude: 0.8, decaySeconds: 1.6),
        _Partial(multiplier: 2, amplitude: 0.45, decaySeconds: 1.2),
        _Partial(multiplier: 3, amplitude: 0.3, decaySeconds: 1.0),
        _Partial(multiplier: 4, amplitude: 0.18, decaySeconds: 0.9),
      ],
    );
  }

  static Uint8List _generateWaveform({
    required double frequency,
    required List<_Partial> partials,
    double durationSeconds = 1.5,
    double overallGain = 0.6,
  }) {
    final totalSamples = (durationSeconds * _sampleRate).round();
    final dataLength = totalSamples * 2;
    final bytes = Uint8List(44 + dataLength);
    final buffer = ByteData.view(bytes.buffer);

    // WAV header
    buffer.setUint32(0, 0x52494646); // 'RIFF'
    buffer.setUint32(4, 36 + dataLength, Endian.little);
    buffer.setUint32(8, 0x57415645); // 'WAVE'
    buffer.setUint32(12, 0x666d7420); // 'fmt '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1 size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, 1, Endian.little); // Mono channel
    buffer.setUint32(24, _sampleRate.toInt(), Endian.little);
    buffer.setUint32(28, (_sampleRate * 2).toInt(), Endian.little); // Byte rate
    buffer.setUint16(32, 2, Endian.little); // Block align
    buffer.setUint16(34, 16, Endian.little); // Bits per sample
    buffer.setUint32(36, 0x64617461); // 'data'
    buffer.setUint32(40, dataLength, Endian.little);

    for (var i = 0; i < totalSamples; i++) {
      final t = i / _sampleRate;
      double sampleValue = 0;
      for (final partial in partials) {
        final envelope = exp(-t / partial.decaySeconds);
        sampleValue +=
            sin(2 * pi * frequency * partial.multiplier * t) * partial.amplitude * envelope;
      }

      final fadeOutStart = durationSeconds * 0.85;
      if (t > fadeOutStart) {
        final fade = max(0, (durationSeconds - t) / (durationSeconds - fadeOutStart));
        sampleValue *= fade;
      }

      sampleValue = (sampleValue * overallGain).clamp(-1.0, 1.0);
      final pcmValue = (sampleValue * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, pcmValue, Endian.little);
    }

    return bytes;
  }
}

class _Partial {
  const _Partial({
    required this.multiplier,
    required this.amplitude,
    required this.decaySeconds,
  });

  final double multiplier;
  final double amplitude;
  final double decaySeconds;
}
