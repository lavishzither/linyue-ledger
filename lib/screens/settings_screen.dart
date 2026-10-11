import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';
import 'ledger_books_screen.dart';
import 'recurring_screen.dart';
import 'templates_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FrostPanel(
              title: '账本',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(state.activeLedger?.name ?? '未选择'),
                subtitle: Text(
                  state.personaLabel().isEmpty ? '切换人群与分类' : '${state.personaLabel()} · 点此管理',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LedgerBooksScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '本月预算',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用本月预算'),
                    subtitle: const Text(
                      '开启后首页会显示已用/剩余进度',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: state.settings.budgetEnabled,
                    activeThumbColor: FrostColors.accentIce,
                    onChanged: (v) => context.read<AppState>().setBudgetEnabled(v),
                  ),
                  if (state.settings.budgetEnabled) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('总预算金额'),
                      subtitle: Text(
                        state.budgetActive
                            ? '¥ ${AppState.money(state.budgetLimit)} · 已用 ¥ ${AppState.money(state.budgetUsed)}'
                            : '点此设置总支出上限（可选）',
                      ),
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: () => _editBudget(context),
                    ),
                    if (state.budgetActive) ...[
                      FrostProgress(
                        value: (state.budgetUsed / state.budgetLimit).clamp(0, 1),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      '分类预算',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    for (final b in state.categoryBudgets)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          state.categoryById(b.categoryId!)?.name ?? '分类',
                        ),
                        subtitle: Text(
                          '¥ ${AppState.money(state.categoryMonthExpense(b.categoryId!))} / ¥ ${AppState.money(b.amount)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editCategoryBudget(
                                context,
                                categoryId: b.categoryId!,
                                initial: b.amount,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: FrostColors.expense,
                              ),
                              onPressed: () async {
                                if (b.id == null) return;
                                await context.read<AppState>().removeCategoryBudget(b.id!);
                              },
                            ),
                          ],
                        ),
                      ),
                    FrostButton(
                      label: '添加分类预算',
                      expanded: true,
                      ghost: true,
                      onPressed: () => _addCategoryBudget(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '分类管理',
              child: Column(
                children: [
                  FrostButton(
                    label: '添加自定义分类',
                    expanded: true,
                    onPressed: () => _addCategory(context),
                  ),
                  const SizedBox(height: 8),
                  for (final c in state.categories.where(
                    (c) => !PersonaPresets.isPlaceholderOther(c.name),
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CategoryIconBadge(iconKey: c.iconKey, size: 32),
                      title: Text(c.name),
                      subtitle: Text(
                        '${c.type.name == 'expense' ? '支出' : '收入'}${c.isSystem ? '' : ' · 自定义'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _renameCategory(context, c.id!, c.name),
                          ),
                          if (!c.isSystem)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: FrostColors.expense),
                              onPressed: () async {
                                final ok = await showFrostConfirm(
                                  context,
                                  title: '删除分类',
                                  message: '确认删除「${c.name}」？有流水的分类无法删除。',
                                );
                                if (!ok || !context.mounted) return;
                                final err = await context.read<AppState>().removeCategory(c.id!);
                                if (context.mounted) {
                                  showFrostToast(context, err ?? '已删除');
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '快捷模板',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('管理常用记账模板'),
                subtitle: Text('已有 ${state.templates.length} 条'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '自动续费',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('会员 / 订阅自动记账'),
                subtitle: Text(
                  state.recurringBills.isEmpty
                      ? 'B站、网易云等模板一键添加'
                      : '已有 ${state.recurringBills.length} 项 · 启用 ${state.recurringBills.where((b) => b.enabled).length} 项',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecurringScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '备份与恢复',
              child: Column(
                children: [
                  FrostButton(
                    label: '导出 JSON',
                    expanded: true,
                    onPressed: () => _exportJson(context),
                  ),
                  const SizedBox(height: 8),
                  FrostButton(
                    label: '导出 CSV',
                    expanded: true,
                    ghost: true,
                    onPressed: () => _exportCsv(context),
                  ),
                  const SizedBox(height: 8),
                  FrostButton(
                    label: '导入备份 JSON',
                    expanded: true,
                    ghost: true,
                    onPressed: () => _importJson(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FrostPanel(
              title: '关于与本地说明',
              child: const Text(
                '凛月记账 v1.0.0\n数据仅保存在本机，不会上传。\n卸载应用或清空数据后，账目将消失。请定期导出备份。',
                style: TextStyle(height: 1.5, color: FrostColors.text),
              ),
            ),
            const SizedBox(height: 12),
            FrostButton(
              label: '清空全部数据',
              danger: true,
              expanded: true,
              onPressed: () async {
                final ok = await showFrostConfirm(
                  context,
                  title: '清空数据',
                  message: '将删除全部流水、霜匣与预算，且不可恢复。',
                  confirmLabel: '确认清空',
                );
                if (!ok || !context.mounted) return;
                final ok2 = await showFrostConfirm(
                  context,
                  title: '再次确认',
                  message: '确定要清空全部数据吗？',
                  confirmLabel: '仍然清空',
                );
                if (ok2 && context.mounted) {
                  await context.read<AppState>().clearAllData();
                  if (context.mounted) showFrostToast(context, '已清空');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBudget(BuildContext context) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController(
      text: (state.monthBudget?.amount ?? 0).toStringAsFixed(2),
    );
    final ok = await _amountDialog(context, '本月总预算', ctrl);
    if (ok && context.mounted) {
      final v = double.tryParse(ctrl.text.trim()) ?? 0;
      await state.setMonthBudgetAmount(v);
    }
  }

  Future<void> _addCategoryBudget(BuildContext context) async {
    final state = context.read<AppState>();
    final expenseCats = state
        .categoriesOf(TxType.expense)
        .where((c) => !PersonaPresets.isPlaceholderOther(c.name))
        .where((c) => !state.categoryBudgets.any((b) => b.categoryId == c.id))
        .toList();
    if (expenseCats.isEmpty) {
      showFrostToast(context, '没有可添加的支出分类');
      return;
    }
    final picked = await showDialog<Category>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostPanel(
          title: '选择分类',
          child: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView(
              children: [
                for (final c in expenseCats)
                  ListTile(
                    leading: CategoryIconBadge(iconKey: c.iconKey, size: 32),
                    title: Text(c.name),
                    onTap: () => Navigator.pop(ctx, c),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked?.id == null || !context.mounted) return;
    await _editCategoryBudget(context, categoryId: picked!.id!, initial: 0);
  }

  Future<void> _editCategoryBudget(
    BuildContext context, {
    required int categoryId,
    required double initial,
  }) async {
    final state = context.read<AppState>();
    final name = state.categoryById(categoryId)?.name ?? '分类';
    final ctrl = TextEditingController(
      text: initial > 0 ? initial.toStringAsFixed(2) : '',
    );
    final ok = await _amountDialog(context, '$name 预算', ctrl);
    if (ok && context.mounted) {
      final v = double.tryParse(ctrl.text.trim()) ?? 0;
      await state.setCategoryBudgetAmount(categoryId, v);
    }
  }

  Future<void> _addCategory(BuildContext context) async {
    var type = TxType.expense;
    final typeOk = await showDialog<TxType>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostPanel(
          title: '选择类型',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostButton(
                label: '支出分类',
                expanded: true,
                danger: true,
                onPressed: () => Navigator.pop(ctx, TxType.expense),
              ),
              const SizedBox(height: 8),
              FrostButton(
                label: '收入分类',
                expanded: true,
                onPressed: () => Navigator.pop(ctx, TxType.income),
              ),
            ],
          ),
        ),
      ),
    );
    if (typeOk == null || !context.mounted) return;
    type = typeOk;
    final result = await showCustomCategoryDialog(context, type: type);
    if (result == null || !context.mounted) return;
    final err = await context.read<AppState>().addCustomCategory(
          name: result.name,
          type: type,
          iconKey: result.iconKey,
        );
    if (context.mounted) showFrostToast(context, err ?? '已添加');
  }

  Future<void> _renameCategory(BuildContext context, int id, String name) async {
    final ctrl = TextEditingController(text: name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostPanel(
          title: '重命名分类',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
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
    if (ok == true && context.mounted) {
      final n = ctrl.text.trim();
      if (n.isNotEmpty) {
        await context.read<AppState>().renameCategory(id, n);
      }
    }
  }

  Future<bool> _amountDialog(
    BuildContext context,
    String title,
    TextEditingController ctrl,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostPanel(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: const InputDecoration(
                  prefixText: '¥ ',
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
    return result ?? false;
  }

  Future<void> _exportJson(BuildContext context) async {
    final state = context.read<AppState>();
    final map = await state.exportJson();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/linyue_$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '凛月记账备份'),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final state = context.read<AppState>();
    final csv = await state.exportCsv();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/linyue_$stamp.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '凛月记账流水 CSV'),
    );
  }

  Future<void> _importJson(BuildContext context) async {
    final ok = await showFrostConfirm(
      context,
      title: '导入备份',
      message: '将覆盖当前账本的流水、霜匣、预算与模板（分类按名称合并）。建议先导出一份备份。',
      confirmLabel: '选择文件',
    );
    if (!ok || !context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;

    final file = result.files.first;
    String raw;
    if (file.bytes != null) {
      raw = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    } else {
      if (!context.mounted) return;
      showFrostToast(context, '无法读取文件');
      return;
    }

    if (!context.mounted) return;
    final state = context.read<AppState>();
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        if (context.mounted) showFrostToast(context, '备份格式不正确');
        return;
      }
      final err = await state.importBackupJson(Map<String, dynamic>.from(data));
      if (context.mounted) showFrostToast(context, err ?? '导入完成');
    } catch (_) {
      if (context.mounted) showFrostToast(context, '解析失败');
    }
  }
}
