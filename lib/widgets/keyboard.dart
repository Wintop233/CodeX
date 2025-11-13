import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../models/sound_library.dart';

class KeyboardSection extends StatefulWidget {
  const KeyboardSection({super.key});

  @override
  State<KeyboardSection> createState() => _KeyboardSectionState();
}

class _KeyboardSectionState extends State<KeyboardSection> {
  final Record _recorder = Record();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  String? _statusMessage;

  final List<_KeyData> _keys = const <_KeyData>[
    _KeyData(label: 'C', semitoneOffset: 0),
    _KeyData(label: 'D', semitoneOffset: 2),
    _KeyData(label: 'E', semitoneOffset: 4),
    _KeyData(label: 'F', semitoneOffset: 5),
    _KeyData(label: 'G', semitoneOffset: 7),
    _KeyData(label: 'A', semitoneOffset: 9),
    _KeyData(label: 'B', semitoneOffset: 11),
  ];

  @override
  void dispose() {
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording(SoundLibrary library) async {
    if (!_isRecording) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() => _statusMessage = '录音权限被拒绝');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final filename =
          'keyboard_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = p.join(directory.path, filename);
      await _recorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        samplingRate: 44100,
        bitRate: 128000,
      );
      setState(() {
        _isRecording = true;
        _statusMessage = '录音中…再次点击以完成';
      });
    } else {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _statusMessage = path != null ? '录音完成' : '录音未保存';
      });
      if (path != null) {
        library.setKeyboardRecording(File(path));
      }
    }
  }

  Future<void> _playNote(SoundLibrary library, _KeyData key) async {
    final sample = library.keyboardPresetSample();
    if (sample.file == null && sample.assetPath == null && sample.bytes == null) {
      setState(() => _statusMessage = '请先录制自定义音色');
      return;
    }
    await _player.stop();
    final rate = pow(2, key.semitoneOffset / 12);
    await _player.setPlaybackRate(PlaybackRate(rate: rate.toDouble()));
    if (sample.file != null) {
      await _player.play(DeviceFileSource(sample.file!.path));
    } else if (sample.assetPath != null) {
      await _player.play(AssetSource(sample.assetPath!));
    } else if (sample.bytes != null) {
      await _player.play(BytesSource(sample.bytes!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SoundLibrary>(
      builder: (context, library, _) {
        return CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          navigationBar: const CupertinoNavigationBar(
            middle: Text('音色键盘'),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '音色选择',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .navTitleTextStyle
                        .copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  CupertinoSegmentedControl<InstrumentVoice>(
                    groupValue: library.selectedVoice,
                    onValueChanged: (voice) {
                      if (voice == InstrumentVoice.custom &&
                          library.keyboardRecording == null) {
                        setState(() => _statusMessage = '请先录制自定义音色');
                        return;
                      }
                      library.setVoice(voice);
                    },
                    children: const {
                      InstrumentVoice.piano: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('钢琴'),
                      ),
                      InstrumentVoice.electric: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('电子琴'),
                      ),
                      InstrumentVoice.custom: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('自定义'),
                      ),
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: () => _toggleRecording(library),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_isRecording ? '停止并保存' : '录制自定义音色'),
                        ),
                      ),
                    ],
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage!,
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(color: CupertinoColors.systemGrey),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '触键演奏',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .navTitleTextStyle
                        .copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: CupertinoColors.systemGrey4,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _keys
                            .map(
                              (key) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: GestureDetector(
                                    onTapDown: (_) => _playNote(library, key),
                                    child: Container(
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          colors: [
                                            CupertinoColors.white,
                                            CupertinoColors.systemGrey5,
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: CupertinoColors.systemGrey4,
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Text(
                                          key.label,
                                          style: CupertinoTheme.of(context)
                                              .textTheme
                                              .textStyle
                                              .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeyData {
  const _KeyData({required this.label, required this.semitoneOffset});

  final String label;
  final int semitoneOffset;
}
