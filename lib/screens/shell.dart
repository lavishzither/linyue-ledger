import 'package:flutter/material.dart';

import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';
import 'home_screen.dart';
import 'ledger_screen.dart';
import 'piggy_screen.dart';
import 'stats_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _statsTab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenAnalysis: () => setState(() {
          _index = 2;
          _statsTab = 1;
        }),
        onOpenPiggy: () => setState(() => _index = 3),
      ),
      const LedgerScreen(),
      StatsScreen(key: ValueKey(_statsTab), initialTab: _statsTab),
      const PiggyScreen(),
    ];

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: FrostColors.bgPanel,
            border: Border(top: BorderSide(color: FrostColors.border, width: 2)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                _tab(0, Icons.account_balance_wallet_outlined, '霜衡'),
                _tab(1, Icons.menu_book_outlined, '霜页'),
                _tab(2, Icons.pie_chart_outline, '清点'),
                _tab(3, Icons.inventory_2_outlined, '霜匣'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i, IconData icon, String label) {
    final selected = _index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _index = i;
          if (i != 2) _statsTab = 0;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? FrostColors.accentIce : FrostColors.textDim,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? FrostColors.balance : FrostColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
