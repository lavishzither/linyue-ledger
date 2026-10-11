import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/theme/frost_theme.dart';
import '../screens/onboarding_screen.dart';
import '../screens/shell.dart';
import '../state/app_state.dart';

class QingshuangApp extends StatelessWidget {
  const QingshuangApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: '凛月记账',
        debugShowCheckedModeBanner: false,
        theme: FrostTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Consumer<AppState>(
          builder: (context, s, _) {
            if (s.loading) {
              return const MistScaffold(
                child: Center(
                  child: Text(
                    '凛月记账',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: FrostColors.balance,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              );
            }
            if (!s.settings.onboarded) {
              return const OnboardingScreen();
            }
            return const AppShell();
          },
        ),
      ),
    );
  }
}

class MistScaffold extends StatelessWidget {
  const MistScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FrostColors.bgBase, FrostColors.bgMistEnd, FrostColors.bgBase],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: child,
      ),
    );
  }
}
