import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';
import 'add_tx_screen.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final grouped = state.ledgerGrouped;
    final monthLabel = DateFormat('yyyy年MM月').format(state.ledgerMonth);

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('霜页'),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final m = state.ledgerMonth;
                state.setLedgerMonth(DateTime(m.year, m.month - 1));
              },
            ),
            Center(
              child: Text(monthLabel, style: const TextStyle(fontSize: 13)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final m = state.ledgerMonth;
                state.setLedgerMonth(DateTime(m.year, m.month + 1));
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: state.setLedgerQuery,
                decoration: InputDecoration(
                  hintText: '搜索备注或金额',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: FrostColors.bgPanel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(0),
                    borderSide: const BorderSide(color: FrostColors.border, width: 2),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: FrostColors.border, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(
                    label: '全部',
                    selected: state.ledgerTypeFilter == null,
                    onTap: () => state.setLedgerTypeFilter(null),
                  ),
                  _chip(
                    label: '支出',
                    selected: state.ledgerTypeFilter == TxType.expense,
                    onTap: () => state.setLedgerTypeFilter(TxType.expense),
                  ),
                  _chip(
                    label: '收入',
                    selected: state.ledgerTypeFilter == TxType.income,
                    onTap: () => state.setLedgerTypeFilter(TxType.income),
                  ),
                  ...state.categories
                      .where((c) => !PersonaPresets.isPlaceholderOther(c.name))
                      .map((Category c) {
                    final id = c.id;
                    return _chip(
                      label: c.name,
                      selected: state.ledgerCategoryFilter == id,
                      onTap: () => state.setLedgerCategoryFilter(
                        state.ledgerCategoryFilter == id ? null : id,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: grouped.isEmpty
                  ? const Center(
                      child: Text(
                        '未找到相关霜页',
                        style: TextStyle(color: FrostColors.textDim),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 6),
                            child: Row(
                              children: [
                                Text(
                                  AppState.dayLabel(entry.key),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: FrostColors.text,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _daySummary(entry.value),
                                  style: const TextStyle(
                                    color: FrostColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final t in entry.value)
                            _TxTile(tx: t),
                        ],
                      ],
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: FrostColors.accentIce,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: FrostColors.border, width: 2),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTxScreen()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? FrostColors.accentIce.withValues(alpha: 0.3) : FrostColors.bgPanel,
            border: Border.all(
              color: selected ? FrostColors.accentIce : FrostColors.border,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: FrostColors.text,
            ),
          ),
        ),
      ),
    );
  }

  String _daySummary(List<Transaction> list) {
    final exp = list.where((t) => t.type == TxType.expense).fold(0.0, (s, t) => s + t.amount);
    final inc = list.where((t) => t.type == TxType.income).fold(0.0, (s, t) => s + t.amount);
    return '支 ${exp.toStringAsFixed(0)} · 收 ${inc.toStringAsFixed(0)}';
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cat = state.categoryById(tx.categoryId);
    final color = tx.type == TxType.expense ? FrostColors.expense : FrostColors.income;
    final sign = tx.type == TxType.expense ? '-' : '+';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTxScreen(existing: tx)),
          );
        },
        onLongPress: () async {
          final ok = await showFrostConfirm(
            context,
            title: '删除记录',
            message: '确认删除此记录？',
          );
          if (ok && context.mounted) {
            await context.read<AppState>().removeTransaction(tx.id!);
          }
        },
        child: FrostPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CategoryIconBadge(iconKey: cat?.iconKey ?? 'other'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat?.name ?? '未分类', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Builder(
                      builder: (_) {
                        final fund = state.fundAccountById(tx.fundAccountId)?.name;
                        final sub = [
                          if (fund != null) fund,
                          if (tx.note.isNotEmpty) tx.note,
                        ].join(' · ');
                        if (sub.isEmpty) return const SizedBox.shrink();
                        return Text(
                          sub,
                          style: const TextStyle(color: FrostColors.textDim, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Text(
                '$sign${AppState.money(tx.amount)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
