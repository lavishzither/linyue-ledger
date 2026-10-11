import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

class FundAccountsScreen extends StatelessWidget {
  const FundAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.fundAccounts;
    final base = state.fundBaseTotal;

    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('资金账户')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FrostPanel(
              title: '底仓合计',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¥ ${AppState.money(base)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: FrostColors.balance,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '当前合计 ¥ ${AppState.money(state.fundAccounts.fold(0.0, (s, a) => s + state.accountEffectiveBalance(a)))}',
                    style: const TextStyle(color: FrostColors.textDim, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '当前 = 底仓 ± 该账户流水；可用余额再减去霜匣',
                    style: TextStyle(color: FrostColors.textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '点账户可改底仓；记账时选择账户会影响当前余额',
              style: TextStyle(color: FrostColors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const FrostPanel(
                child: Text('暂无账户', style: TextStyle(color: FrostColors.textDim)),
              )
            else
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _editBalance(context, a),
                    child: FrostPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          CategoryIconBadge(iconKey: a.iconKey, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '底仓 ¥ ${AppState.money(a.balance)}',
                                  style: const TextStyle(
                                    color: FrostColors.textDim,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '¥ ${AppState.money(state.accountEffectiveBalance(a))}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: FrostColors.balance,
                            ),
                          ),
                          if (!a.isPreset)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: FrostColors.expense,
                              ),
                              onPressed: () async {
                                final ok = await showFrostConfirm(
                                  context,
                                  title: '删除账户',
                                  message: '确认删除「${a.name}」？其底仓将不再计入。',
                                );
                                if (!ok || !context.mounted) return;
                                final err =
                                    await context.read<AppState>().removeFundAccount(a);
                                if (context.mounted) {
                                  showFrostToast(context, err ?? '已删除');
                                }
                              },
                            )
                          else
                            const Icon(Icons.edit, size: 16, color: FrostColors.textDim),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            FrostButton(
              label: '添加自定义账户',
              expanded: true,
              onPressed: () => _addCustom(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBalance(BuildContext context, FundAccount account) async {
    final ctrl = TextEditingController(text: account.balance.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: FrostPanel(
          title: '调整「${account.name}」底仓',
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
      final v = double.tryParse(ctrl.text.trim()) ?? 0;
      await context.read<AppState>().saveFundAccount(account.copyWith(balance: v));
      if (context.mounted) showFrostToast(context, '已更新');
    }
  }

  Future<void> _addCustom(BuildContext context) async {
    final lid = context.read<AppState>().activeLedgerId;
    if (lid == null) return;
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    var iconKey = 'wallet';
    const iconChoices = ['wallet', 'card', 'bank', 'cash', 'alipay', 'wechat', 'transfer'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          child: FrostPanel(
            title: '自定义账户',
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      hintText: '如：招商银行、花呗',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: balCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    decoration: const InputDecoration(
                      labelText: '当前底仓',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('图标', style: TextStyle(fontSize: 12, color: FrostColors.textDim)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in iconChoices)
                        InkWell(
                          onTap: () => setLocal(() => iconKey = k),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: iconKey == k
                                    ? FrostColors.accentIce
                                    : FrostColors.border,
                                width: 2,
                              ),
                              color: iconKey == k
                                  ? FrostColors.accentIce.withValues(alpha: 0.15)
                                  : null,
                            ),
                            child: CategoryIconBadge(iconKey: k, size: 32),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
                          label: '添加',
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      showFrostToast(context, '请填写名称');
      return;
    }
    final state = context.read<AppState>();
    if (state.fundAccounts.any((a) => a.name == name)) {
      showFrostToast(context, '已有同名账户');
      return;
    }
    final bal = double.tryParse(balCtrl.text.trim()) ?? 0;
    await state.saveFundAccount(
      FundAccount(
        ledgerId: lid,
        name: name,
        kind: FundKind.custom,
        balance: bal,
        iconKey: iconKey,
      ),
    );
    if (context.mounted) showFrostToast(context, '已添加');
  }
}
