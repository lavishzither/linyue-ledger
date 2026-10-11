import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../data/presets/recurring_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.recurringBills;
    final monthlyTotal = list
        .where((b) => b.enabled && b.period == RecurringPeriod.monthly)
        .fold(0.0, (s, b) => s + b.amount);
    final yearlyTotal = list
        .where((b) => b.enabled && b.period == RecurringPeriod.yearly)
        .fold(0.0, (s, b) => s + b.amount);

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('自动续费'),
          actions: [
            TextButton(
              onPressed: () => _openTemplates(context),
              child: const Text('模板库', style: TextStyle(color: FrostColors.accentIce)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FrostPanel(
              title: '说明',
              child: const Text(
                '到期日打开 App 时会自动记一笔支出，并推算下次扣款日。金额为参考价，可按实际修改。',
                style: TextStyle(color: FrostColors.textDim, height: 1.45, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '启用中合计',
              child: Text(
                '每月约 ¥ ${AppState.money(monthlyTotal)} · 每年约 ¥ ${AppState.money(yearlyTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FrostButton(
                    label: '从模板添加',
                    onPressed: () => _openTemplates(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FrostButton(
                    label: '自定义',
                    ghost: true,
                    onPressed: () => _editBill(context, null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              const FrostPanel(
                child: Text(
                  '还没有自动续费\n可从模板库一键添加 B站、网易云等',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FrostColors.textDim, height: 1.5),
                ),
              )
            else
              for (final b in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FrostPanel(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        CategoryIconBadge(
                          iconKey: state.categoryById(b.categoryId)?.iconKey ?? 'sub',
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _editBill(context, b),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: b.enabled
                                        ? FrostColors.text
                                        : FrostColors.textDim,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${b.period.label} ¥ ${AppState.money(b.amount)} · '
                                  '下次 ${DateFormat('yyyy年M月d日').format(b.nextDueAt)}'
                                  '${_dueHint(b)}',
                                  style: const TextStyle(
                                    color: FrostColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  [
                                    state.categoryById(b.categoryId)?.name,
                                    state.fundAccountById(b.fundAccountId)?.name,
                                  ].whereType<String>().join(' · '),
                                  style: const TextStyle(
                                    color: FrostColors.textDim,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Switch(
                          value: b.enabled,
                          activeThumbColor: FrostColors.accentIce,
                          onChanged: (v) =>
                              context.read<AppState>().toggleRecurringBill(b, v),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: FrostColors.expense,
                          ),
                          onPressed: () async {
                            final ok = await showFrostConfirm(
                              context,
                              title: '删除续费',
                              message: '确认删除「${b.title}」？已记流水不会删除。',
                            );
                            if (ok && context.mounted) {
                              await context.read<AppState>().removeRecurringBill(b.id!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _dueHint(RecurringBill b) {
    final d = b.daysUntil;
    if (d == null) return '';
    if (d < 0) return ' · 待补记';
    if (d == 0) return ' · 今天';
    if (d <= 7) return ' · $d天后';
    return '';
  }

  Future<void> _openTemplates(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _RecurringTemplatesPage()),
    );
  }

  Future<void> _editBill(BuildContext context, RecurringBill? existing) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _RecurringEditorPage(existing: existing)),
    );
  }
}

class _RecurringTemplatesPage extends StatefulWidget {
  const _RecurringTemplatesPage();

  @override
  State<_RecurringTemplatesPage> createState() => _RecurringTemplatesPageState();
}

class _RecurringTemplatesPageState extends State<_RecurringTemplatesPage> {
  RecurringPeriod? _filter;

  @override
  Widget build(BuildContext context) {
    final list = _filter == null
        ? RecurringPresets.all
        : RecurringPresets.ofPeriod(_filter!);

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('续费模板库')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _chip('全部', null),
                  const SizedBox(width: 8),
                  _chip('每月', RecurringPeriod.monthly),
                  const SizedBox(width: 8),
                  _chip('每年', RecurringPeriod.yearly),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FrostPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          CategoryIconBadge(iconKey: p.iconKey, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${p.period.label} ¥ ${AppState.money(p.amount)}'
                                  '${p.hint.isEmpty ? '' : ' · ${p.hint}'}',
                                  style: const TextStyle(
                                    color: FrostColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FrostButton(
                            label: '添加',
                            onPressed: () => _addFromPreset(context, p),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, RecurringPeriod? p) {
    final selected = _filter == p;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = p),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? FrostColors.accentIce.withValues(alpha: 0.25)
                : FrostColors.bgPanel,
            border: Border.all(
              color: selected ? FrostColors.accentIce : FrostColors.border,
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

  Future<void> _addFromPreset(BuildContext context, RecurringPreset p) async {
    final state = context.read<AppState>();
    final lid = state.activeLedgerId;
    if (lid == null) return;
    final catId = await state.ensureSubscriptionCategoryId();
    if (!context.mounted) return;
    final now = DateTime.now();
    final next = RecurringBill.advance(
      DateTime(now.year, now.month, now.day),
      p.period,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RecurringEditorPage(
          existing: RecurringBill(
            ledgerId: lid,
            title: p.title,
            amount: p.amount,
            categoryId: catId,
            fundAccountId: state.defaultFundAccount?.id,
            period: p.period,
            nextDueAt: next,
            note: '自动续费·${p.title}',
            templateKey: p.key,
            createdAt: now,
          ),
          fromPreset: true,
        ),
      ),
    );
  }
}

class _RecurringEditorPage extends StatefulWidget {
  const _RecurringEditorPage({this.existing, this.fromPreset = false});

  final RecurringBill? existing;
  final bool fromPreset;

  @override
  State<_RecurringEditorPage> createState() => _RecurringEditorPageState();
}

class _RecurringEditorPageState extends State<_RecurringEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late RecurringPeriod _period;
  late DateTime _nextDue;
  int? _categoryId;
  int? _fundAccountId;
  late bool _enabled;
  String? _templateKey;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(2),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _period = e?.period ?? RecurringPeriod.monthly;
    _nextDue = e?.nextDueAt ?? DateTime.now().add(const Duration(days: 30));
    _categoryId = e?.categoryId;
    _fundAccountId = e?.fundAccountId;
    _enabled = e?.enabled ?? true;
    _templateKey = e?.templateKey;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cats = state
        .categoriesOf(TxType.expense)
        .where((c) => !PersonaPresets.isPlaceholderOther(c.name))
        .toList();
    _categoryId ??= cats.isEmpty ? null : cats.first.id;
    _fundAccountId ??= state.defaultFundAccount?.id;
    final isNew = widget.existing?.id == null;

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(isNew ? '添加续费' : '编辑续费')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FrostPanel(
              title: '基本信息',
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FrostButton(
                          label: '每月',
                          ghost: _period != RecurringPeriod.monthly,
                          onPressed: () =>
                              setState(() => _period = RecurringPeriod.monthly),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FrostButton(
                          label: '每年',
                          ghost: _period != RecurringPeriod.yearly,
                          onPressed: () =>
                              setState(() => _period = RecurringPeriod.yearly),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '下次扣款 ${DateFormat('yyyy年M月d日').format(_nextDue)}',
                    ),
                    subtitle: const Text('到日打开 App 会自动记账'),
                    trailing: const Icon(Icons.event_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        locale: const Locale('zh', 'CN'),
                        helpText: '选择日期',
                        cancelText: '取消',
                        confirmText: '确定',
                        initialDate: _nextDue,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _nextDue = picked);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用自动记账'),
                    value: _enabled,
                    activeThumbColor: FrostColors.accentIce,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '分类',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cats)
                    GestureDetector(
                      onTap: () => setState(() => _categoryId = c.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _categoryId == c.id
                              ? FrostColors.accentIce.withValues(alpha: 0.25)
                              : FrostColors.bgBase,
                          border: Border.all(
                            color: _categoryId == c.id
                                ? FrostColors.accentIce
                                : FrostColors.border,
                            width: 2,
                          ),
                        ),
                        child: Text(c.name),
                      ),
                    ),
                ],
              ),
            ),
            if (state.fundAccounts.isNotEmpty) ...[
              const SizedBox(height: 12),
              FrostPanel(
                title: '扣款账户',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in state.fundAccounts)
                      GestureDetector(
                        onTap: () => setState(() => _fundAccountId = a.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _fundAccountId == a.id
                                ? FrostColors.accentViolet.withValues(alpha: 0.2)
                                : FrostColors.bgBase,
                            border: Border.all(
                              color: _fundAccountId == a.id
                                  ? FrostColors.accentViolet
                                  : FrostColors.border,
                              width: 2,
                            ),
                          ),
                          child: Text(a.name),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FrostPanel(
              title: '备注',
              child: TextField(
                controller: _note,
                maxLength: 40,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '写入流水的备注',
                ),
              ),
            ),
            const SizedBox(height: 20),
            FrostButton(
              label: '保存',
              expanded: true,
              onPressed: _save,
            ),
            if (widget.fromPreset) ...[
              const SizedBox(height: 8),
              const Text(
                '保存后不会立刻扣款；到「下次扣款」日打开 App 才会记入',
                style: TextStyle(color: FrostColors.textDim, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (title.isEmpty || amount < 0.01) {
      showFrostToast(context, '请填写名称与金额');
      return;
    }
    if (_categoryId == null) {
      showFrostToast(context, '请选择分类');
      return;
    }
    final state = context.read<AppState>();
    final lid = state.activeLedgerId;
    if (lid == null) return;
    final e = widget.existing;
    await state.saveRecurringBill(
      RecurringBill(
        id: e?.id,
        ledgerId: lid,
        title: title,
        amount: amount,
        categoryId: _categoryId!,
        fundAccountId: _fundAccountId,
        period: _period,
        nextDueAt: _nextDue,
        note: _note.text.trim(),
        enabled: _enabled,
        templateKey: _templateKey ?? e?.templateKey,
        lastPostedAt: e?.lastPostedAt,
        createdAt: e?.createdAt ?? DateTime.now(),
      ),
    );
    if (mounted) {
      showFrostToast(context, '已保存');
      Navigator.pop(context);
      if (widget.fromPreset && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }
}
