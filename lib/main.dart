import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'models/sound_library.dart';
import 'widgets/drum_pad_grid.dart';
import 'widgets/keyboard.dart';
import 'widgets/sequencer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SoundLibrary(),
      child: const ToneCrafterApp(),
    ),
  );
}

class ToneCrafterApp extends StatelessWidget {
  const ToneCrafterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: ToneCrafterHome(),
    );
  }
}

class ToneCrafterHome extends StatefulWidget {
  const ToneCrafterHome({super.key});

  @override
  State<ToneCrafterHome> createState() => _ToneCrafterHomeState();
}

class _ToneCrafterHomeState extends State<ToneCrafterHome> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    KeyboardSection(),
    DrumPadGrid(),
    SequencerSection(),
  ];

  final List<BottomNavigationBarItem> _items = const [
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.music_note),
      label: '键盘',
    ),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.square_grid_3x3),
      label: '鼓垫',
    ),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.waveform),
      label: '音序器',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: _items,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => _tabs[index],
        );
      },
    );
  }
}
