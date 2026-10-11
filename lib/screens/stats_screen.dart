import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

enum _Range { thisMonth, lastMonth, days90 }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  _Range _range = _Range.thisMonth;
  int? _selectedSlice;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabs.index = widget.initialTab.clamp(0, 1);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  (DateTime from, DateTime to, DateTime month) _bounds() {
    final now = DateTime.now();
    switch (_range) {
      case _Range.thisMonth:
        final from = DateTime(now.year, now.month, 1);
        return (from, DateTime(now.year, now.month + 1, 1), from);
      case _Range.lastMonth:
        final from = DateTime(now.year, now.month - 1, 1);
        return (from, DateTime(now.year, now.month, 1), from);
      case _Range.days90:
        final to = DateTime(now.year, now.month, now.day + 1);
        final from = to.subtract(const Duration(days: 90));
        return (from, to, DateTime(now.year, now.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('清点'),
          bottom: TabBar(
            controller: _tabs,
            labelColor: FrostColors.balance,
            unselectedLabelColor: FrostColors.textDim,
            indicatorColor: FrostColors.accentIce,
            tabs: const [
              Tab(text: '对照'),
              Tab(text: '分析'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _rangeChip('本月', _Range.thisMonth),
                  const SizedBox(width: 8),
                  _rangeChip('上月', _Range.lastMonth),
                  const SizedBox(width: 8),
                  _rangeChip('近90天', _Range.days90),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _CompareTab(
                    range: _range,
                    bounds: _bounds(),
                    selectedSlice: _selectedSlice,
                    onSelect: (i) => setState(() => _selectedSlice = i),
                  ),
                  _AnalysisTab(bounds: _bounds()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeChip(String label, _Range r) {
    final selected = _range == r;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _range = r;
          _selectedSlice = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? FrostColors.accentViolet.withValues(alpha: 0.2) : FrostColors.bgPanel,
            border: Border.all(
              color: selected ? FrostColors.accentViolet : FrostColors.border,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareTab extends StatelessWidget {
  const _CompareTab({
    required this.range,
    required this.bounds,
    required this.selectedSlice,
    required this.onSelect,
  });

  final _Range range;
  final (DateTime, DateTime, DateTime) bounds;
  final int? selectedSlice;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final (from, to, month) = bounds;
    final map = state.expenseByCategory(from: from, to: to);
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (s, e) => s + e.value);
    final income = state.transactions
        .where((t) =>
            t.type.name == 'income' &&
            !t.occurredAt.isBefore(from) &&
            t.occurredAt.isBefore(to))
        .fold(0.0, (s, t) => s + t.amount);
    final expense = total;

    final slices = <({String label, double value, Color color})>[];
    for (var i = 0; i < entries.length; i++) {
      final cat = state.categoryById(entries[i].key);
      slices.add((
        label: cat?.name ?? '其他',
        value: entries[i].value,
        color: FrostColors.piePalette[i % FrostColors.piePalette.length],
      ));
    }

    final centerValue = selectedSlice == null
        ? AppState.money(total)
        : AppState.money(slices[selectedSlice!].value);
    final centerLabel = selectedSlice == null
        ? '总支出'
        : slices[selectedSlice!].label;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FrostPanel(
          title: '收支总览',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OverviewBars(income: income, expense: expense),
              const SizedBox(height: 8),
              Text(
                '结余 ¥ ${AppState.money(income - expense)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: income - expense < 0 ? FrostColors.expense : FrostColors.income,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FrostPanel(
          title: '分类对照',
          child: Column(
            children: [
              if (slices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('尚无花销可析', style: TextStyle(color: FrostColors.textDim)),
                )
              else ...[
                PixelPieChart(
                  slices: slices,
                  selectedIndex: selectedSlice,
                  onSelected: onSelect,
                  centerLabel: centerLabel,
                  centerValue: '¥ $centerValue',
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < slices.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, color: slices[i].color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(slices[i].label)),
                        Text(
                          '${(slices[i].value / total * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: FrostColors.textDim, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppState.money(slices[i].value),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (range == _Range.thisMonth)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '对照月：${DateFormat('yyyy-MM').format(month)}',
              style: const TextStyle(color: FrostColors.textDim, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab({required this.bounds});

  final (DateTime, DateTime, DateTime) bounds;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final (from, to, month) = bounds;
    final map = state.expenseByCategory(from: from, to: to);
    final expense = map.values.fold(0.0, (s, v) => s + v);
    final income = state.transactions
        .where((t) =>
            t.type.name == 'income' &&
            !t.occurredAt.isBefore(from) &&
            t.occurredAt.isBefore(to))
        .fold(0.0, (s, t) => s + t.amount);

    final prevFrom = DateTime(month.year, month.month - 1, 1);
    final prevTo = DateTime(month.year, month.month, 1);
    final prevExpense = state
        .expenseByCategory(from: prevFrom, to: prevTo)
        .values
        .fold(0.0, (s, v) => s + v);
    final deltaPct = prevExpense <= 0 ? null : (expense - prevExpense) / prevExpense * 100;

    final now = DateTime.now();
    final daysPassed = month.year == now.year && month.month == now.month
        ? now.day
        : DateTime(month.year, month.month + 1, 0).day;
    final daily = daysPassed <= 0 ? 0.0 : expense / daysPassed;

    final ranking = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = ranking.take(5).toList();
    final maxTop = top.isEmpty ? 1.0 : top.first.value;

    final trend = state.last6MonthExpenses();
    final maxTrend = trend.map((e) => e.expense).fold(0.0, math.max);
    final hints = state.anomalyHints(month);

    final isCurrentMonth =
        month.year == now.year && month.month == now.month;
    final budgetOn = state.budgetActive && isCurrentMonth;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FrostPanel(
          title: '花销笺',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¥ ${AppState.money(expense)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: FrostColors.balance,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                deltaPct == null
                    ? '较上月 —'
                    : '较上月 ${deltaPct >= 0 ? '↑' : '↓'}${deltaPct.abs().toStringAsFixed(0)}%',
                style: TextStyle(
                  color: deltaPct == null
                      ? FrostColors.textDim
                      : (deltaPct >= 0 ? FrostColors.expense : FrostColors.income),
                ),
              ),
              const SizedBox(height: 8),
              Text('日均 ¥ ${AppState.money(daily)}',
                  style: const TextStyle(color: FrostColors.textDim)),
              Text(
                '结余 ¥ ${AppState.money(income - expense)}',
                style: TextStyle(
                  color: income - expense < 0 ? FrostColors.expense : FrostColors.income,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (budgetOn) ...[
          const SizedBox(height: 12),
          FrostPanel(
            title: '预算对照',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '已用 ${AppState.money(state.budgetUsed)} / 预算 ${AppState.money(state.budgetLimit)}',
                ),
                const SizedBox(height: 8),
                FrostProgress(
                  value: (state.budgetUsed / state.budgetLimit).clamp(0, 1),
                ),
                const SizedBox(height: 6),
                Text(
                  state.budgetLeft >= 0
                      ? '剩余 ${AppState.money(state.budgetLeft)}'
                      : '超支 ${AppState.money(-state.budgetLeft)}',
                  style: TextStyle(
                    color: state.budgetLeft >= 0
                        ? FrostColors.income
                        : FrostColors.expense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (state.settings.budgetEnabled && !state.budgetActive && isCurrentMonth) ...[
          const SizedBox(height: 12),
          const FrostPanel(
            title: '预算对照',
            child: Text(
              '已开启预算开关，请到设置填写本月预算金额',
              style: TextStyle(color: FrostColors.textDim),
            ),
          ),
        ],
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 12),
          FrostPanel(
            title: '提示',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final h in hints)
                  Text('· $h', style: const TextStyle(color: FrostColors.accentRose, height: 1.5)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FrostPanel(
          title: '分类排行',
          child: top.isEmpty
              ? const Text('尚无花销可析', style: TextStyle(color: FrostColors.textDim))
              : Column(
                  children: [
                    for (final e in top)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(state.categoryById(e.key)?.name ?? '')),
                                Text(AppState.money(e.value)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            FrostProgress(value: e.value / maxTop),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        FrostPanel(
          title: '近六月支出',
          child: SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _TrendPainter(trend: trend, maxV: maxTrend),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final t in trend)
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 0),
                          child: Text(
                            DateFormat('M月').format(t.month),
                            style: const TextStyle(fontSize: 10, color: FrostColors.textDim),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.trend, required this.maxV});

  final List<({DateTime month, double expense})> trend;
  final double maxV;

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.isEmpty) return;
    final barW = size.width / trend.length * 0.5;
    final paint = Paint()..color = FrostColors.accentIce;
    final border = Paint()
      ..color = FrostColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < trend.length; i++) {
      final h = maxV <= 0 ? 0.0 : (trend[i].expense / maxV) * (size.height - 24);
      final x = (i + 0.5) * (size.width / trend.length) - barW / 2;
      final rect = Rect.fromLTWH(x, size.height - 18 - h, barW, h);
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, border);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}
