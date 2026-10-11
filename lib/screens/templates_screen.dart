import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';
import 'add_tx_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.templates;

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('快捷模板')),
        body: list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '还没有模板\n把常用的「咖啡 18」「地铁 4」存起来，首页一点即记',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FrostColors.textDim, height: 1.5),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final t = list[i];
                  final cat = state.categoryById(t.categoryId);
                  final color = t.type == TxType.expense
                      ? FrostColors.expense
                      : FrostColors.income;
                  final sign = t.type == TxType.expense ? '-' : '+';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                                Text(
                                  t.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${cat?.name ?? '未分类'}${t.note.isEmpty ? '' : ' · ${t.note}'}',
                                  style: const TextStyle(
                                    color: FrostColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$sign${AppState.money(t.amount)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _edit(context, t),
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
                                title: '删除模板',
                                message: '确认删除「${t.title}」？',
                              );
                              if (ok && context.mounted) {
                                await context.read<AppState>().removeTemplate(t.id!);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: FrostColors.accentIce,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: FrostColors.border, width: 2),
          ),
          onPressed: () => _edit(context, null),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, QuickTemplate? existing) async {
    final state = context.read<AppState>();
    final lid = state.activeLedgerId;
    if (lid == null) return;

    var type = existing?.type ?? TxType.expense;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    int? categoryId = existing?.categoryId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cats = state
              .categoriesOf(type)
              .where((c) => !PersonaPresets.isPlaceholderOther(c.name))
              .toList();
          if (categoryId != null && !cats.any((c) => c.id == categoryId)) {
            categoryId = cats.isEmpty ? null : cats.first.id;
          }
          categoryId ??= cats.isEmpty ? null : cats.first.id;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: FrostPanel(
              title: existing == null ? '新建模板' : '编辑模板',
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FrostButton(
                            label: '支出',
                            ghost: type != TxType.expense,
                            danger: type == TxType.expense,
                            onPressed: () => setLocal(() {
                              type = TxType.expense;
                              categoryId = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FrostButton(
                            label: '收入',
                            ghost: type != TxType.income,
                            onPressed: () => setLocal(() {
                              type = TxType.income;
                              categoryId = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        hintText: '如：上班咖啡',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                    DropdownButtonFormField<int>(
                      value: categoryId,
                      decoration: const InputDecoration(
                        labelText: '分类',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in cats)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setLocal(() => categoryId = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: '备注（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            label: '保存',
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
        },
      ),
    );

    if (ok != true || !context.mounted) return;
    final title = titleCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (title.isEmpty || amount < 0.01 || categoryId == null) {
      showFrostToast(context, '请填写名称、金额与分类');
      return;
    }
    await context.read<AppState>().saveTemplate(
          QuickTemplate(
            id: existing?.id,
            ledgerId: lid,
            title: title,
            type: type,
            amount: amount,
            categoryId: categoryId!,
            note: noteCtrl.text.trim(),
            sort: existing?.sort ?? 0,
          ),
        );
    if (context.mounted) showFrostToast(context, '已保存');
  }
}

/// 首页快捷条：点模板直接进入记账页
class HomeTemplatesStrip extends StatelessWidget {
  const HomeTemplatesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.templates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '快捷记账',
                style: TextStyle(fontWeight: FontWeight.w700, color: FrostColors.text),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                );
              },
              child: Text(
                list.isEmpty ? '添加模板' : '管理',
                style: const TextStyle(color: FrostColors.accentIce, fontSize: 13),
              ),
            ),
          ],
        ),
        if (list.isEmpty)
          const FrostPanel(
            child: Text(
              '暂无模板，点右上角添加常用金额',
              style: TextStyle(color: FrostColors.textDim, fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = list[i];
                return ActionChip(
                  label: Text('${t.title} ¥${AppState.money(t.amount)}'),
                  backgroundColor: FrostColors.bgPanel,
                  side: const BorderSide(color: FrostColors.border),
                  labelStyle: const TextStyle(
                    color: FrostColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddTxScreen(fromTemplate: t),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
