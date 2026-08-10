import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class JewelryArApp extends StatelessWidget {
  const JewelryArApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Joyería AR',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: appRouter,
    );
  }
}
