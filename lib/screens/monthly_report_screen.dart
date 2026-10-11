import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final m = widget.initialMonth ?? DateTime(now.year, now.month);
    _month = DateTime(m.year, m.month);
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final expense = state.monthExpense(_month);
    final income = state.monthIncome(_month);
    final net = income - expense;
    final prev = DateTime(_month.year, _month.month - 1);
    final prevExp = state.monthExpense(prev);
    final vs = prevExp <= 0 ? null : ((expense - prevExp) / prevExp * 100);
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 1);
    final byCat = state.expenseByCategory(from: from, to: to);
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hints = state.anomalyHints(_month);
    final label = DateFormat('yyyy年M月').format(_month);
    final budgetOn = state.settings.budgetEnabled;
    final budgetAmt = state.monthBudget?.amount ?? 0;
    final isCurrent = _month.year == DateTime.now().year &&
        _month.month == DateTime.now().month;

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('月度报告')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: FrostColors.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FrostPanel(
              title: '收支总览',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('收入 ¥ ${AppState.money(income)}'),
                  Text('支出 ¥ ${AppState.money(expense)}'),
                  const SizedBox(height: 6),
                  Text(
                    '结余 ¥ ${AppState.money(net)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: net < 0 ? FrostColors.expense : FrostColors.income,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vs == null
                        ? '上月无可比支出'
                        : '支出较上月 ${vs >= 0 ? '↑' : '↓'}${vs.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: vs == null
                          ? FrostColors.textDim
                          : (vs >= 0 ? FrostColors.expense : FrostColors.income),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (budgetOn && isCurrent) ...[
              const SizedBox(height: 12),
              FrostPanel(
                title: '预算',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '已用 ¥ ${AppState.money(expense)} / ¥ ${AppState.money(budgetAmt)}',
                    ),
                    const SizedBox(height: 8),
                    FrostProgress(
                      value: budgetAmt <= 0 ? 0 : (expense / budgetAmt).clamp(0, 1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      budgetAmt <= 0
                          ? '尚未设置预算金额'
                          : (expense <= budgetAmt
                              ? '剩余 ¥ ${AppState.money(budgetAmt - expense)}'
                              : '超支 ¥ ${AppState.money(expense - budgetAmt)}'),
                      style: TextStyle(
                        color: budgetAmt > 0 && expense > budgetAmt
                            ? FrostColors.expense
                            : FrostColors.income,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FrostPanel(
              title: '分类花销 Top',
              child: sorted.isEmpty
                  ? const Text('本月暂无支出', style: TextStyle(color: FrostColors.textDim))
                  : Column(
                      children: [
                        for (final e in sorted.take(8))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    state.categoryById(e.key)?.name ?? '未分类',
                                  ),
                                ),
                                Text(
                                  '¥ ${AppState.money(e.value)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    expense <= 0
                                        ? '—'
                                        : '${(e.value / expense * 100).toStringAsFixed(0)}%',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: FrostColors.textDim,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: 12),
              FrostPanel(
                title: '留意',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final h in hints)
                      Text(
                        '· $h',
                        style: const TextStyle(
                          color: FrostColors.accentRose,
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (state.piggies.isNotEmpty) ...[
              const SizedBox(height: 12),
              FrostPanel(
                title: '霜匣进度',
                child: Column(
                  children: [
                    for (final p in state.piggies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${p.name} · ${AppState.money(p.currentAmount)} / ${AppState.money(p.targetAmount)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            FrostProgress(value: p.progress.clamp(0, 1)),
                            if (p.hasMonthlyTarget && isCurrent) ...[
                              const SizedBox(height: 4),
                              Text(
                                '本月存入 ¥ ${AppState.money(state.monthDepositOf(p.id!))} / ${AppState.money(p.monthlyTarget)}',
                                style: const TextStyle(
                                  color: FrostColors.textDim,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FrostPanel(
              title: '一句话',
              child: Text(
                _blurb(expense: expense, income: income, vs: vs, top: sorted.isEmpty
                    ? null
                    : state.categoryById(sorted.first.key)?.name),
                style: const TextStyle(height: 1.5, color: FrostColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _blurb({
    required double expense,
    required double income,
    required double? vs,
    required String? top,
  }) {
    if (expense <= 0 && income <= 0) return '这个月还很安静，记一笔就热闹起来。';
    final parts = <String>[];
    if (income > expense) {
      parts.add('收支有结余，节奏不错。');
    } else if (income > 0) {
      parts.add('支出略紧，留意一下大头分类。');
    } else {
      parts.add('本月暂无收入记录。');
    }
    if (top != null) parts.add('花得最多的是「$top」。');
    if (vs != null) {
      if (vs > 15) {
        parts.add('比上月多花了不少。');
      } else if (vs < -15) {
        parts.add('比上月省下不少。');
      }
    }
    return parts.join('');
  }
}
