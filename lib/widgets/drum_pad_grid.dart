import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../models/sound_library.dart';

class DrumPadGrid extends StatefulWidget {
  const DrumPadGrid({super.key});

  @override
  State<DrumPadGrid> createState() => _DrumPadGridState();
}

class _DrumPadGridState extends State<DrumPadGrid> {
  final Record _recorder = Record();
  bool _isRecording = false;
  int? _recordingPad;
  String? _statusMessage;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _togglePadRecording(SoundLibrary library, int padIndex) async {
    if (!_isRecording) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() => _statusMessage = '录音权限被拒绝');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final filename = 'pad_${padIndex}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = p.join(directory.path, filename);
      await _recorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        samplingRate: 44100,
        bitRate: 128000,
      );
      setState(() {
        _isRecording = true;
        _recordingPad = padIndex;
        _statusMessage = '鼓垫 ${padIndex + 1} 录音中…';
      });
    } else {
      if (_recordingPad != padIndex) {
        setState(() => _statusMessage = '请先结束当前录音');
        return;
      }
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPad = null;
        _statusMessage = path != null ? '鼓垫 ${padIndex + 1} 录音完成' : '录音取消';
      });
      if (path != null) {
        library.setPadRecording(padIndex, File(path));
      }
    }
  }

  Future<void> _triggerPad(SoundLibrary library, int padIndex) async {
    final sample = library.padSample(padIndex);
    final file = sample.file;
    if (file == null || !file.existsSync()) {
      setState(() => _statusMessage = '鼓垫 ${padIndex + 1} 还没有音色，请长按录制');
      return;
    }
    final player = AudioPlayer();
    await player.play(DeviceFileSource(file.path));
    await player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SoundLibrary>(
      builder: (context, library, _) {
        return CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          navigationBar: const CupertinoNavigationBar(
            middle: Text('打击垫鼓组'),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '长按鼓垫开始/结束录音',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(color: CupertinoColors.systemGrey),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage!,
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(color: CupertinoColors.activeBlue),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        final isRecordingPad = _isRecording && _recordingPad == index;
                        final hasRecording = library.padRecordings[index] != null;
                        return _DrumPad(
                          index: index,
                          isRecording: isRecordingPad,
                          hasRecording: hasRecording,
                          onPressed: () => _triggerPad(library, index),
                          onLongPress: () => _togglePadRecording(library, index),
                        );
                      },
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

class _DrumPad extends StatelessWidget {
  const _DrumPad({
    required this.index,
    required this.isRecording,
    required this.hasRecording,
    required this.onPressed,
    required this.onLongPress,
  });

  final int index;
  final bool isRecording;
  final bool hasRecording;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final baseColor = hasRecording
        ? CupertinoColors.activeGreen
        : CupertinoColors.systemGrey4;
    final highlight = isRecording ? CupertinoColors.systemRed : baseColor;
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
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
          border: Border.all(
            color: highlight,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Pad ${index + 1}',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              isRecording ? CupertinoIcons.mic_fill : CupertinoIcons.waveform_path,
              size: 32,
              color: highlight,
            ),
            const SizedBox(height: 8),
            Text(
              isRecording
                  ? '录音中…'
                  : hasRecording
                      ? '点击播放'
                      : '长按录制',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
