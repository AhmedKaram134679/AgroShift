import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme.dart';
import '../presentation/main_navigation_shell.dart';

class AgroShiftApp extends StatelessWidget {
  const AgroShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'AgroShift — أجروشيفت',
        debugShowCheckedModeBanner: false,
        theme: AgroTheme.lightTheme,
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: MainNavigationShell(),
        ),
      ),
    );
  }
}
