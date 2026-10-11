import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

class AddTxScreen extends StatefulWidget {
  const AddTxScreen({
    super.key,
    this.initialType = TxType.expense,
    this.existing,
    this.fromTemplate,
  });

  final TxType initialType;
  final Transaction? existing;
  final QuickTemplate? fromTemplate;

  @override
  State<AddTxScreen> createState() => _AddTxScreenState();
}

class _AddTxScreenState extends State<AddTxScreen> {
  late TxType _type;
  late TextEditingController _amount;
  late TextEditingController _note;
  late TextEditingController _piggyAmount;
  int? _categoryId;
  int? _fundAccountId;
  late DateTime _date;

  bool _saveToPiggy = false;
  int? _piggyId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final tpl = widget.fromTemplate;
    _type = e?.type ?? tpl?.type ?? widget.initialType;
    _amount = TextEditingController(
      text: e != null
          ? e.amount.toStringAsFixed(2)
          : (tpl != null ? tpl.amount.toStringAsFixed(2) : ''),
    );
    _note = TextEditingController(text: e?.note ?? tpl?.note ?? '');
    _piggyAmount = TextEditingController();
    _categoryId = e?.categoryId ?? tpl?.categoryId;
    _fundAccountId = e?.fundAccountId;
    _date = e?.occurredAt ?? DateTime.now();
    _amount.addListener(_onIncomeAmountChanged);
  }

  void _onIncomeAmountChanged() {
    if (!_saveToPiggy || _type != TxType.income) return;
    // 不强制覆盖用户已改的存入金额；仅在空时跟收入同步
    if (_piggyAmount.text.trim().isEmpty) {
      _piggyAmount.text = _amount.text;
    }
  }

  @override
  void dispose() {
    _amount.removeListener(_onIncomeAmountChanged);
    _amount.dispose();
    _note.dispose();
    _piggyAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cats = state
        .categoriesOf(_type)
        .where((c) => !PersonaPresets.isPlaceholderOther(c.name))
        .toList();
    if (_categoryId != null &&
        !cats.any((c) => c.id == _categoryId) &&
        cats.isNotEmpty) {
      _categoryId = cats.first.id;
    }
    _categoryId ??= cats.isEmpty ? null : cats.first.id;
    _fundAccountId ??= state.defaultFundAccount?.id;
    if (_fundAccountId != null &&
        !state.fundAccounts.any((a) => a.id == _fundAccountId)) {
      _fundAccountId = state.defaultFundAccount?.id;
    }
    if (_saveToPiggy && _piggyId == null && state.piggies.isNotEmpty) {
      _piggyId = state.piggies.first.id;
    }

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.existing == null ? '记账' : '改账'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FrostPanel(
              child: Row(
                children: [
                  Expanded(
                    child: FrostButton(
                      label: '支出',
                      danger: _type == TxType.expense,
                      ghost: _type != TxType.expense,
                      onPressed: () => setState(() {
                        _type = TxType.expense;
                        _saveToPiggy = false;
                        final next = state
                            .categoriesOf(_type)
                            .where((c) => !PersonaPresets.isPlaceholderOther(c.name));
                        _categoryId = next.firstOrNull?.id;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FrostButton(
                      label: '收入',
                      ghost: _type != TxType.income,
                      onPressed: () => setState(() {
                        _type = TxType.income;
                        final next = state
                            .categoriesOf(_type)
                            .where((c) => !PersonaPresets.isPlaceholderOther(c.name));
                        _categoryId = next.firstOrNull?.id;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '金额',
              child: TextField(
                controller: _amount,
                autofocus: widget.existing == null && widget.fromTemplate == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: FrostColors.balance,
                ),
                decoration: const InputDecoration(
                  prefixText: '¥ ',
                  border: InputBorder.none,
                  hintText: '0.00',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (state.fundAccounts.isNotEmpty)
              FrostPanel(
                title: _type == TxType.expense ? '从哪个账户出' : '存入哪个账户',
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
                                ? FrostColors.accentIce.withValues(alpha: 0.25)
                                : FrostColors.bgBase,
                            border: Border.all(
                              color: _fundAccountId == a.id
                                  ? FrostColors.accentIce
                                  : FrostColors.border,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CategoryIconBadge(iconKey: a.iconKey, size: 28),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '¥ ${AppState.money(state.accountEffectiveBalance(a))}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: FrostColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (state.fundAccounts.isNotEmpty) const SizedBox(height: 12),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryIconBadge(iconKey: c.iconKey, size: 28),
                            const SizedBox(width: 6),
                            Text(c.name),
                          ],
                        ),
                      ),
                    ),
                  // 原「其他」位：自定义入口
                  GestureDetector(
                    onTap: () => _openCustomCategory(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: FrostColors.accentViolet.withValues(alpha: 0.15),
                        border: Border.all(color: FrostColors.accentViolet, width: 2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CategoryIconBadge(iconKey: 'custom', size: 28),
                          SizedBox(width: 6),
                          Text(
                            '自定义',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_type == TxType.income && widget.existing == null) ...[
              const SizedBox(height: 12),
              FrostPanel(
                title: '存入霜匣',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('同时划入霜匣'),
                      subtitle: const Text(
                        '可自定义存入金额，不必等于全部收入',
                        style: TextStyle(fontSize: 12, color: FrostColors.textDim),
                      ),
                      value: _saveToPiggy,
                      activeThumbColor: FrostColors.accentIce,
                      onChanged: (v) {
                        setState(() {
                          _saveToPiggy = v;
                          if (v) {
                            _piggyId ??= state.piggies.firstOrNull?.id;
                            if (_piggyAmount.text.trim().isEmpty) {
                              _piggyAmount.text = _amount.text;
                            }
                          }
                        });
                      },
                    ),
                    if (_saveToPiggy) ...[
                      if (state.piggies.isEmpty)
                        const Text(
                          '尚无霜匣，请先到霜匣页创建任务',
                          style: TextStyle(color: FrostColors.expense, fontSize: 12),
                        )
                      else ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('选择霜匣', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in state.piggies)
                              GestureDetector(
                                onTap: () => setState(() => _piggyId = p.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _piggyId == p.id
                                        ? FrostColors.accentViolet.withValues(alpha: 0.2)
                                        : FrostColors.bgBase,
                                    border: Border.all(
                                      color: _piggyId == p.id
                                          ? FrostColors.accentViolet
                                          : FrostColors.border,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    '${AppState.scaleLabel(p.scale)} · ${p.name}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _piggyAmount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: '存入金额（可自定义）',
                            prefixText: '¥ ',
                            border: OutlineInputBorder(),
                            helperText: '可小于或等于本次收入',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _quickChip('全部', () {
                              _piggyAmount.text = _amount.text;
                              setState(() {});
                            }),
                            _quickChip('一半', () {
                              final a = double.tryParse(_amount.text.trim()) ?? 0;
                              _piggyAmount.text = (a / 2).toStringAsFixed(2);
                              setState(() {});
                            }),
                            _quickChip('1/3', () {
                              final a = double.tryParse(_amount.text.trim()) ?? 0;
                              _piggyAmount.text = (a / 3).toStringAsFixed(2);
                              setState(() {});
                            }),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FrostPanel(
              title: '日期',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${_date.year}年${_date.month}月${_date.day}日',
                ),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    locale: const Locale('zh', 'CN'),
                    helpText: '选择日期',
                    cancelText: '取消',
                    confirmText: '确定',
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '备注',
              child: TextField(
                controller: _note,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: '可选',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FrostButton(
              label: '记账',
              expanded: true,
              onPressed: () => _submit(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomCategory(BuildContext context) async {
    final result = await showCustomCategoryDialog(context, type: _type);
    if (result == null || !context.mounted) return;
    final err = await context.read<AppState>().addCustomCategory(
          name: result.name,
          type: _type,
          iconKey: result.iconKey,
        );
    if (!context.mounted) return;
    if (err != null) {
      showFrostToast(context, err);
      return;
    }
    final created = context
        .read<AppState>()
        .categoriesOf(_type)
        .where((c) => c.name == result.name)
        .firstOrNull;
    setState(() => _categoryId = created?.id);
    showFrostToast(context, '已创建并选用「${result.name}」');
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: FrostColors.border, width: 2),
          color: FrostColors.bgBase,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount < 0.01) {
      showFrostToast(context, '尚未填写金额');
      return;
    }
    if (amount > 9999999.99) {
      showFrostToast(context, '数额过大');
      return;
    }
    if (_categoryId == null) {
      showFrostToast(context, '请选择分类');
      return;
    }

    final state = context.read<AppState>();
    final lid = state.activeLedgerId;
    if (lid == null) return;
    if (state.fundAccounts.isNotEmpty && _fundAccountId == null) {
      showFrostToast(context, '请选择资金账户');
      return;
    }
    if (_type == TxType.expense && _fundAccountId != null) {
      final acc = state.fundAccountById(_fundAccountId);
      if (acc != null) {
        final avail = state.accountEffectiveBalance(acc);
        // 编辑时先加回本笔原支出
        final old = widget.existing;
        final credit = (old != null &&
                old.type == TxType.expense &&
                old.fundAccountId == _fundAccountId)
            ? old.amount
            : 0.0;
        if (amount > avail + credit + 1e-9) {
          showFrostToast(context, '该账户余额不足');
          return;
        }
      }
    }

    double? piggyAmt;
    PiggyBank? piggy;
    if (_type == TxType.income && _saveToPiggy && widget.existing == null) {
      if (state.piggies.isEmpty || _piggyId == null) {
        showFrostToast(context, '请先选择霜匣');
        return;
      }
      piggyAmt = double.tryParse(_piggyAmount.text.trim());
      if (piggyAmt == null || piggyAmt < 0.01) {
        showFrostToast(context, '请填写存入金额');
        return;
      }
      if (piggyAmt > amount + 1e-9) {
        showFrostToast(context, '存入不能超过本次收入');
        return;
      }
      // 记入收入后可用余额会增加 amount，再划出 piggyAmt
      // 划出前可用余额 = 当前 + amount（尚未写入时要按写入后算）
      final afterIncome = state.availableBalance + amount;
      if (piggyAmt > afterIncome + 1e-9) {
        showFrostToast(context, '数额不足');
        return;
      }
      piggy = state.piggies.firstWhere((p) => p.id == _piggyId);
    }

    final now = DateTime.now();
    final occurred = DateTime(
      _date.year,
      _date.month,
      _date.day,
      now.hour,
      now.minute,
      now.second,
    );
    final tx = Transaction(
      id: widget.existing?.id,
      ledgerId: lid,
      type: _type,
      amount: amount,
      categoryId: _categoryId!,
      fundAccountId: _fundAccountId,
      note: _note.text.trim(),
      occurredAt: occurred,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await state.saveTransaction(tx);

    if (piggy != null && piggyAmt != null) {
      // 重新取最新 piggy（金额可能未变）
      final latest = state.piggies.firstWhere((p) => p.id == piggy!.id);
      final err = await state.transferPiggy(
        piggy: latest,
        direction: PiggyDirection.into,
        amount: piggyAmt,
      );
      if (context.mounted && err != null) {
        showFrostToast(context, err);
        return;
      }
      if (context.mounted) {
        showFrostToast(context, '已记入，并存入霜匣 ¥ ${AppState.money(piggyAmt)}');
      }
    }

    if (context.mounted) Navigator.pop(context);
  }
}
