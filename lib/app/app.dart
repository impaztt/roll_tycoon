import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/country/presentation/country_root.dart';
import 'theme.dart';

class PastelParkApp extends StatelessWidget {
  const PastelParkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pastel Park Tycoon',
      debugShowCheckedModeBanner: false,
      theme: PastelTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
      ],
      home: const CountryRoot(),
    );
  }
}
