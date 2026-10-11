import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/presets/recurring_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';
import 'add_tx_screen.dart';
import 'fund_accounts_screen.dart';
import 'ledger_books_screen.dart';
import 'monthly_report_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';
import 'templates_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenAnalysis, this.onOpenPiggy});

  final VoidCallback? onOpenAnalysis;
  final VoidCallback? onOpenPiggy;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bal = state.availableBalance;
    final expense = state.monthExpense();
    final income = state.monthIncome();
    final lastExpense = state.monthExpense(DateTime(DateTime.now().year, DateTime.now().month - 1));
    final delta = lastExpense <= 0
        ? null
        : ((expense - lastExpense) / lastExpense * 100);
    final week = state.weekSummary();

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('凛月记账'),
              if (state.activeLedger != null)
                Text(
                  '${state.activeLedger!.name} · ${state.personaLabel()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: FrostColors.textDim,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: '账本',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LedgerBooksScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FundAccountsScreen()),
                );
              },
              child: FrostPanel(
                title: '可用余额',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            '¥ ${AppState.money(bal)}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: bal < 0 ? FrostColors.expense : FrostColors.balance,
                            ),
                          ),
                        ),
                        const Text(
                          '资金账户',
                          style: TextStyle(
                            color: FrostColors.accentIce,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: FrostColors.accentIce),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (state.fundAccounts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final a in state.fundAccounts.take(6))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: FrostColors.bgBase,
                                  border: Border.all(color: FrostColors.border, width: 1),
                                ),
                                child: Text(
                                  '${a.name} ${AppState.money(state.accountEffectiveBalance(a))}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: FrostColors.textDim,
                                  ),
                                ),
                              ),
                            if (state.fundAccounts.length > 6)
                              const Text(
                                '…',
                                style: TextStyle(color: FrostColors.textDim, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    Text(
                      '本月支出 ${AppState.money(expense)} · 收入 ${AppState.money(income)}',
                      style: const TextStyle(color: FrostColors.textDim, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '净资产 ¥ ${AppState.money(state.netWorth)} · 底仓 ¥ ${AppState.money(state.fundBaseTotal)}',
                      style: const TextStyle(color: FrostColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            if (state.settings.budgetEnabled) ...[
              const SizedBox(height: 12),
              FrostPanel(
                title: '本月预算',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.budgetActive) ...[
                      Text(
                        '总预算 已用 ¥ ${AppState.money(state.budgetUsed)} / ¥ ${AppState.money(state.budgetLimit)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      FrostProgress(
                        value: (state.budgetUsed / state.budgetLimit).clamp(0, 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.budgetLeft >= 0
                            ? '剩余 ¥ ${AppState.money(state.budgetLeft)}'
                            : '超支 ¥ ${AppState.money(-state.budgetLeft)}',
                        style: TextStyle(
                          color: state.budgetLeft >= 0
                              ? FrostColors.income
                              : FrostColors.expense,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (state.categoryBudgets.isEmpty)
                      const Text(
                        '已启用预算，请到设置填写总预算或分类预算',
                        style: TextStyle(color: FrostColors.textDim, fontSize: 13),
                      ),
                    if (state.categoryBudgets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final b in state.categoryBudgets) ...[
                        Builder(
                          builder: (_) {
                            final used = state.categoryMonthExpense(b.categoryId!);
                            final left = b.amount - used;
                            final name =
                                state.categoryById(b.categoryId!)?.name ?? '分类';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '$name ¥ ${AppState.money(used)} / ¥ ${AppState.money(b.amount)}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  FrostProgress(
                                    value: b.amount <= 0
                                        ? 0
                                        : (used / b.amount).clamp(0, 1),
                                  ),
                                  Text(
                                    left >= 0
                                        ? '剩余 ¥ ${AppState.money(left)}'
                                        : '超支 ¥ ${AppState.money(-left)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: left >= 0
                                          ? FrostColors.income
                                          : FrostColors.expense,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: onOpenAnalysis,
              child: FrostPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('本月花销', style: TextStyle(color: FrostColors.textDim, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '¥ ${AppState.money(expense)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: FrostColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      delta == null
                          ? '—'
                          : '${delta >= 0 ? '↑' : '↓'}${delta.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: delta == null
                            ? FrostColors.textDim
                            : (delta >= 0 ? FrostColors.expense : FrostColors.income),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: FrostColors.textDim),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '本周小结',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '支出 ¥ ${AppState.money(week.expense)} · 收入 ¥ ${AppState.money(week.income)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    week.topCategory == null
                        ? '本周暂无支出分类'
                        : '花得最多：${week.topCategory}',
                    style: const TextStyle(color: FrostColors.textDim, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    week.vsLastWeekPct == null
                        ? '上周无可比支出'
                        : '较上周 ${week.vsLastWeekPct! >= 0 ? '↑' : '↓'}${week.vsLastWeekPct!.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: week.vsLastWeekPct == null
                          ? FrostColors.textDim
                          : (week.vsLastWeekPct! >= 0
                              ? FrostColors.expense
                              : FrostColors.income),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FrostButton(
                    label: '记支出',
                    onPressed: () => _openAdd(context, TxType.expense),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FrostButton(
                    label: '记收入',
                    onPressed: () => _openAdd(context, TxType.income),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FrostButton(
                    label: '积一笔',
                    ghost: true,
                    onPressed: onOpenPiggy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FrostButton(
                    label: '月度报告',
                    ghost: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MonthlyReportScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FrostButton(
                    label: '自动续费',
                    ghost: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecurringScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (state.lastRecurringPosted > 0) ...[
              const SizedBox(height: 8),
              FrostPanel(
                child: Text(
                  '已自动记入 ${state.lastRecurringPosted} 笔续费支出',
                  style: const TextStyle(
                    color: FrostColors.accentViolet,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (state.upcomingRecurring.isNotEmpty) ...[
              const SizedBox(height: 12),
              FrostPanel(
                title: '即将续费',
                child: Column(
                  children: [
                    for (final b in state.upcomingRecurring.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${b.title} · ${b.period.label}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '¥ ${AppState.money(b.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: FrostColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RecurringScreen()),
                          );
                        },
                        child: const Text(
                          '管理',
                          style: TextStyle(color: FrostColors.accentIce, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const HomeTemplatesStrip(),
            const SizedBox(height: 20),
            const Text(
              '最近',
              style: TextStyle(fontWeight: FontWeight.w700, color: FrostColors.text),
            ),
            const SizedBox(height: 8),
            if (state.recentFive.isEmpty)
              const FrostPanel(
                child: Text('尚无记录', style: TextStyle(color: FrostColors.textDim)),
              )
            else
              ...state.recentFive.map((t) {
                final cat = state.categoryById(t.categoryId);
                final sign = t.type == TxType.expense ? '-' : '+';
                final color =
                    t.type == TxType.expense ? FrostColors.expense : FrostColors.income;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTxScreen(existing: t),
                        ),
                      );
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
                                Text(cat?.name ?? '未分类',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (t.note.isNotEmpty)
                                  Text(t.note,
                                      style: const TextStyle(
                                          color: FrostColors.textDim, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$sign${AppState.money(t.amount)}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                AppState.dayLabel(t.occurredAt),
                                style: const TextStyle(
                                  color: FrostColors.textDim,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _openAdd(BuildContext context, TxType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTxScreen(initialType: type)),
    );
  }
}
