import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'ui/screens/menu_screen.dart';
import 'ui/screens/song_select_screen.dart';

class MeowzartApp extends StatelessWidget {
  const MeowzartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meowzart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: MenuScreen.routeName,
      routes: {
        MenuScreen.routeName: (_) => const MenuScreen(),
        SongSelectScreen.routeName: (_) => const SongSelectScreen(),
      },
    );
  }
}
