import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/sound_library.dart';

class SequencerSection extends StatefulWidget {
  const SequencerSection({super.key});

  @override
  State<SequencerSection> createState() => _SequencerSectionState();
}

class _SequencerSectionState extends State<SequencerSection> {
  final List<SequenceStep?> _steps = List<SequenceStep?>.filled(16, null);
  final Map<int, AudioPlayer> _activePlayers = {};
  Timer? _timer;
  bool _isPlaying = false;
  int _currentStep = 0;
  int _tempo = 100;
  String? _statusMessage;

  @override
  void dispose() {
    _timer?.cancel();
    for (final player in _activePlayers.values) {
      player.dispose();
    }
    super.dispose();
  }

  Duration get _stepDuration {
    final beatDurationMs = (60000 / _tempo);
    return Duration(milliseconds: (beatDurationMs / 4).round());
  }

  Future<void> _togglePlayback(SoundLibrary library) async {
    if (_isPlaying) {
      _stopPlayback();
      return;
    }
    if (_steps.every((step) => step == null)) {
      setState(() => _statusMessage = '请先在音序器中添加音符');
      return;
    }
    setState(() {
      _isPlaying = true;
      _currentStep = 0;
      _statusMessage = '播放中…';
    });
    _timer = Timer.periodic(_stepDuration, (_) {
      _playStep(library, _currentStep);
      setState(() {
        _currentStep = (_currentStep + 1) % _steps.length;
      });
    });
  }

  void _stopPlayback() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _isPlaying = false;
      _statusMessage = '播放停止';
    });
  }

  Future<void> _playStep(SoundLibrary library, int stepIndex) async {
    final step = _steps[stepIndex];
    if (step == null) {
      return;
    }
    final sample = _resolveSample(library, step.sampleId);
    if (sample == null) {
      setState(() => _statusMessage = '音色不可用，请重新选择');
      return;
    }
    final player = AudioPlayer();
    _activePlayers[stepIndex]?.dispose();
    _activePlayers[stepIndex] = player;
    final rate = pow(2, step.transpose / 12);
    await player.setPlaybackRate(PlaybackRate(rate: rate.toDouble()));
    player.onPlayerComplete.listen((event) {
      _activePlayers.remove(stepIndex)?.dispose();
    });
    if (sample.file != null) {
      await player.play(DeviceFileSource(sample.file!.path));
    } else if (sample.assetPath != null) {
      await player.play(AssetSource(sample.assetPath!));
    } else if (sample.bytes != null) {
      await player.play(BytesSource(sample.bytes!));
    }
  }

  void _toggleStep(int index, SoundLibrary library) {
    setState(() {
      if (_steps[index] != null) {
        _steps[index] = null;
      } else {
        final sample = _defaultSample(library);
        if (sample == null) {
          _statusMessage = '请先录制一个音色';
          return;
        }
        _steps[index] = SequenceStep(sampleId: sample.id);
      }
    });
  }

  SoundSample? _defaultSample(SoundLibrary library) {
    final available = _availableSamples(library);
    if (available.isEmpty) {
      return null;
    }
    return available.first;
  }

  List<SoundSample> _availableSamples(SoundLibrary library) {
    final samples = <SoundSample>[];
    final keyboard = library.keyboardPresetSample();
    if (keyboard.assetPath != null || keyboard.file != null || keyboard.bytes != null) {
      samples.add(keyboard);
    }
    library.padRecordings.forEach((index, file) {
      if (file != null) {
        samples.add(library.padSample(index));
      }
    });
    return samples;
  }

  SoundSample? _resolveSample(SoundLibrary library, String sampleId) {
    if (sampleId == 'keyboard') {
      final sample = library.keyboardPresetSample();
      if (sample.assetPath == null && sample.file == null && sample.bytes == null) {
        return null;
      }
      return sample;
    }
    if (sampleId.startsWith('pad_')) {
      final padIndex = int.tryParse(sampleId.split('_').last);
      if (padIndex == null) {
        return null;
      }
      final sample = library.padSample(padIndex);
      if (sample.file == null) {
        return null;
      }
      return sample;
    }
    return null;
  }

  Future<void> _editStep(int index, SoundLibrary library) async {
    final samples = _availableSamples(library);
    if (samples.isEmpty) {
      setState(() => _statusMessage = '当前没有可用的音色');
      return;
    }
    final initialStep = _steps[index] ?? SequenceStep(sampleId: samples.first.id);
    var selectedSampleIndex = samples.indexWhere((element) => element.id == initialStep.sampleId);
    if (selectedSampleIndex == -1) {
      selectedSampleIndex = 0;
    }
    var transpose = initialStep.transpose;
    final result = await showCupertinoModalPopup<SequenceStep>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 360,
              decoration: const BoxDecoration(
                color: CupertinoColors.systemGroupedBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const Text(
                        '编辑音符',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(
                          SequenceStep(
                            sampleId: samples[selectedSampleIndex].id,
                            transpose: transpose,
                          ),
                        ),
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: selectedSampleIndex),
                      itemExtent: 36,
                      onSelectedItemChanged: (value) {
                        setModalState(() => selectedSampleIndex = value);
                      },
                      children: [
                        for (final sample in samples)
                          Center(
                            child: Text(sample.label),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('音高微调: ${transpose >= 0 ? '+' : ''}$transpose 半音'),
                  CupertinoSlider(
                    min: -12,
                    max: 12,
                    value: transpose.toDouble(),
                    divisions: 24,
                    onChanged: (value) => setModalState(() => transpose = value.round()),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (result != null) {
      setState(() {
        _steps[index] = result;
      });
    }
  }

  void _clearSequence() {
    setState(() {
      for (var i = 0; i < _steps.length; i++) {
        _steps[i] = null;
      }
      _statusMessage = '音序器已清空';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SoundLibrary>(
      builder: (context, library, _) {
        return CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          navigationBar: const CupertinoNavigationBar(
            middle: Text('音序器'),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoSlider(
                          value: _tempo.toDouble(),
                          min: 60,
                          max: 160,
                          divisions: 100,
                          onChanged: (value) => setState(() => _tempo = value.round()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('$_tempo BPM'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_statusMessage != null)
                    Text(
                      _statusMessage!,
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .copyWith(color: CupertinoColors.systemGrey),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        final isActive = step != null;
                        final isPlayingStep = _isPlaying && index == _currentStep;
                        return GestureDetector(
                          onTap: () => _toggleStep(index, library),
                          onLongPress: () => _editStep(index, library),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? CupertinoColors.activeBlue
                                  : CupertinoColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isPlayingStep
                                  ? const [
                                      BoxShadow(
                                        color: CupertinoColors.activeBlue,
                                        blurRadius: 16,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : const [
                                      BoxShadow(
                                        color: CupertinoColors.systemGrey4,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Step ${index + 1}',
                                    style: TextStyle(
                                      color: isActive
                                          ? CupertinoColors.white
                                          : CupertinoColors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isActive)
                                    Text(
                                      step!.sampleId == 'keyboard'
                                          ? '键盘'
                                          : step.sampleId.replaceAll('pad_', 'Pad '),
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: _isPlaying
                              ? CupertinoColors.destructiveRed
                              : CupertinoColors.activeBlue,
                          onPressed: () => _togglePlayback(library),
                          child: Text(_isPlaying ? '停止播放' : '开始播放'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: _clearSequence,
                        child: const Text('清空'),
                      ),
                    ],
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

class SequenceStep {
  SequenceStep({required this.sampleId, this.transpose = 0});

  final String sampleId;
  final int transpose;
}
