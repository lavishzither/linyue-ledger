import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

class PiggyScreen extends StatelessWidget {
  const PiggyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final big = state.bigPiggies;
    final small = state.smallPiggies;

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('霜匣')),
        body: (big.isEmpty && small.isEmpty)
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '尚无霜匣\n可创建大任务（如旅游）或小任务（如买件好物）',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FrostColors.textDim, height: 1.5),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('大任务', '长远目标，如旅游、换机'),
                  if (big.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('暂无大任务', style: TextStyle(color: FrostColors.textDim, fontSize: 12)),
                    )
                  else
                    for (final p in big) _PiggyCard(piggy: p),
                  const SizedBox(height: 8),
                  _sectionTitle('小任务', '短期小目标，如买一件东西'),
                  if (small.isEmpty)
                    const Text('暂无小任务', style: TextStyle(color: FrostColors.textDim, fontSize: 12))
                  else
                    for (final p in small) _PiggyCard(piggy: p),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: FrostColors.accentIce,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: FrostColors.border, width: 2),
          ),
          onPressed: () => _create(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(hint, style: const TextStyle(color: FrostColors.textDim, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _PiggyEditorPage()),
    );
    if (created == true && context.mounted) {
      // 列表由 AppState 刷新
    }
  }
}

/// 整页编辑，避免键盘把弹窗顶破
class _PiggyEditorPage extends StatefulWidget {
  const _PiggyEditorPage({this.existing});

  final PiggyBank? existing;

  @override
  State<_PiggyEditorPage> createState() => _PiggyEditorPageState();
}

class _PiggyEditorPageState extends State<_PiggyEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _monthly;
  late final TextEditingController _note;
  late PiggyScale _scale;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController(
      text: e == null ? '' : e.targetAmount.toStringAsFixed(2),
    );
    _monthly = TextEditingController(
      text: e != null && e.monthlyTarget > 0 ? e.monthlyTarget.toStringAsFixed(2) : '',
    );
    _note = TextEditingController(text: e?.note ?? '');
    _scale = e?.scale ?? PiggyScale.small;
    _targetDate = e?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _monthly.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = double.tryParse(_target.text.trim()) ?? 0;
    final monthly = double.tryParse(_monthly.text.trim()) ?? 0;
    final state = context.read<AppState>();
    final lid = state.activeLedgerId;
    if (name.isEmpty || target < 0.01 || lid == null) {
      showFrostToast(context, '请填写名称与总目标');
      return;
    }
    final existing = widget.existing;
    await state.savePiggy(
      existing == null
          ? PiggyBank(
              ledgerId: lid,
              name: name,
              targetAmount: target,
              monthlyTarget: monthly,
              scale: _scale,
              note: _note.text.trim(),
              createdAt: DateTime.now(),
              targetDate: _targetDate,
            )
          : existing.copyWith(
              name: name,
              targetAmount: target,
              monthlyTarget: monthly,
              scale: _scale,
              note: _note.text.trim(),
              targetDate: _targetDate,
              clearTargetDate: _targetDate == null,
            ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(isEdit ? '编辑霜匣' : '新建霜匣')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            FrostPanel(
              child: Row(
                children: [
                  Expanded(
                    child: FrostButton(
                      label: '大任务',
                      ghost: _scale != PiggyScale.big,
                      onPressed: () => setState(() => _scale = PiggyScale.big),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FrostButton(
                      label: '小任务',
                      ghost: _scale != PiggyScale.small,
                      onPressed: () => setState(() => _scale = PiggyScale.small),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '基本信息',
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '名称',
                      hintText: _scale == PiggyScale.big ? '如：去云南旅游' : '如：买一双鞋',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _target,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    decoration: const InputDecoration(
                      labelText: '总目标金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _monthly,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    decoration: const InputDecoration(
                      labelText: '每月小目标（可选）',
                      prefixText: '¥ ',
                      helperText: '用于对照本月真实存入进度',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _targetDate == null
                          ? '目标完成日（可选）'
                          : '目标日 ${DateFormat('yyyy年M月d日').format(_targetDate!)}',
                    ),
                    subtitle: const Text('用于倒计时与日均需存'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_targetDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _targetDate = null),
                          ),
                        const Icon(Icons.event_outlined),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        locale: const Locale('zh', 'CN'),
                        helpText: '选择日期',
                        cancelText: '取消',
                        confirmText: '确定',
                        initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _targetDate = picked);
                    },
                  ),
                  TextField(
                    controller: _note,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FrostButton(
              label: isEdit ? '保存' : '创建',
              expanded: true,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
            FrostButton(
              label: '取消',
              expanded: true,
              ghost: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PiggyCard extends StatelessWidget {
  const _PiggyCard({required this.piggy});

  final PiggyBank piggy;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pct = (piggy.progress * 100).clamp(0, 999);
    final monthIn = state.monthDepositOf(piggy.id!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PiggyDetailScreen(piggyId: piggy.id!)),
          );
        },
        child: FrostPanel(
          title: '${AppState.scaleLabel(piggy.scale)} · ${piggy.name}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (piggy.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(piggy.note, style: const TextStyle(color: FrostColors.textDim, fontSize: 12)),
                ),
              FrostProgress(value: piggy.progress.clamp(0, 1)),
              const SizedBox(height: 8),
              Text(
                '总目标 ${AppState.money(piggy.currentAmount)} / ${AppState.money(piggy.targetAmount)}  ·  ${pct.toStringAsFixed(0)}%',
                style: const TextStyle(color: FrostColors.textDim, fontSize: 12),
              ),
              if (piggy.hasMonthlyTarget) ...[
                const SizedBox(height: 8),
                FrostProgress(
                  value: piggy.monthlyTarget <= 0
                      ? 0
                      : (monthIn / piggy.monthlyTarget).clamp(0, 1),
                ),
                const SizedBox(height: 4),
                Text(
                  '本月小目标 ${AppState.money(monthIn)} / ${AppState.money(piggy.monthlyTarget)}'
                  '${monthIn >= piggy.monthlyTarget ? ' · 已达成' : ' · 还差 ${AppState.money(piggy.monthlyTarget - monthIn)}'}',
                  style: TextStyle(
                    color: monthIn >= piggy.monthlyTarget
                        ? FrostColors.income
                        : FrostColors.accentRose,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              Builder(
                builder: (context) {
                  final hint = state.piggyCountdownHint(piggy);
                  if (hint == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      hint,
                      style: const TextStyle(
                        color: FrostColors.accentViolet,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PiggyDetailScreen extends StatelessWidget {
  const PiggyDetailScreen({super.key, required this.piggyId});

  final int piggyId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final piggy = state.piggies.where((p) => p.id == piggyId).firstOrNull;
    if (piggy == null) {
      return const Scaffold(body: Center(child: Text('霜匣已删除')));
    }

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(piggy.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showFrostConfirm(
                  context,
                  title: '删除霜匣',
                  message: '霜匣内金额将退回可用余额',
                );
                if (ok && context.mounted) {
                  await context.read<AppState>().removePiggy(piggy);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FrostPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppState.scaleLabel(piggy.scale),
                    style: const TextStyle(color: FrostColors.accentViolet, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '¥ ${AppState.money(piggy.currentAmount)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: FrostColors.balance,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FrostProgress(value: piggy.progress.clamp(0, 1)),
                  const SizedBox(height: 8),
                  Text(
                    '总目标 ${AppState.money(piggy.targetAmount)}',
                    style: const TextStyle(color: FrostColors.textDim),
                  ),
                  if (piggy.note.isNotEmpty)
                    Text(piggy.note, style: const TextStyle(color: FrostColors.textDim)),
                  if (piggy.achievedAt != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('已满额', style: TextStyle(color: FrostColors.accentRose)),
                    ),
                  if (piggy.targetDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '目标日 ${DateFormat('yyyy年M月d日').format(piggy.targetDate!)}',
                      style: const TextStyle(color: FrostColors.textDim),
                    ),
                  ],
                  Builder(
                    builder: (context) {
                      final hint = state.piggyCountdownHint(piggy);
                      if (hint == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          hint,
                          style: const TextStyle(
                            color: FrostColors.accentViolet,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (piggy.hasMonthlyTarget) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final monthIn = state.monthDepositOf(piggy.id!);
                  final ok = monthIn >= piggy.monthlyTarget;
                  return FrostPanel(
                    title: '本月小目标对照',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('计划存入 ¥ ${AppState.money(piggy.monthlyTarget)}'),
                        Text('实际存入 ¥ ${AppState.money(monthIn)}'),
                        const SizedBox(height: 8),
                        FrostProgress(
                          value: (monthIn / piggy.monthlyTarget).clamp(0, 1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ok
                              ? '本月已达成'
                              : '还差 ¥ ${AppState.money(piggy.monthlyTarget - monthIn)}',
                          style: TextStyle(
                            color: ok ? FrostColors.income : FrostColors.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            FrostButton(
              label: '编辑目标',
              expanded: true,
              ghost: true,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PiggyEditorPage(existing: piggy),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FrostButton(
              label: '转入',
              expanded: true,
              onPressed: () => _transfer(context, piggy, PiggyDirection.into),
            ),
            const SizedBox(height: 8),
            FrostButton(
              label: '转出',
              expanded: true,
              ghost: true,
              onPressed: () => _transfer(context, piggy, PiggyDirection.outOf),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transfer(
    BuildContext context,
    PiggyBank piggy,
    PiggyDirection direction,
  ) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostPanel(
          title: direction == PiggyDirection.into ? '转入霜匣' : '转出霜匣',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FrostButton(
                      label: '取消',
                      ghost: true,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FrostButton(
                      label: '确认',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && context.mounted) {
      final amount = double.tryParse(ctrl.text.trim()) ?? 0;
      final err = await context.read<AppState>().transferPiggy(
            piggy: piggy,
            direction: direction,
            amount: amount,
          );
      if (context.mounted) {
        showFrostToast(context, err ?? '已记入');
      }
    }
  }
}
