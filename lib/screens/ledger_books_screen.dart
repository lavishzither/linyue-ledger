import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

class LedgerBooksScreen extends StatelessWidget {
  const LedgerBooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('账本')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '不同人群使用不同分类。点选即可切换当前账本。',
              style: TextStyle(color: FrostColors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final book in state.ledgers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () async {
                    await context.read<AppState>().switchLedger(book.id!);
                    if (context.mounted) {
                      showFrostToast(context, '已切换至 ${book.name}');
                      Navigator.pop(context);
                    }
                  },
                  child: FrostPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                PersonaPresets.label(book.persona),
                                style: const TextStyle(
                                  color: FrostColors.textDim,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.activeLedgerId == book.id)
                          const Text(
                            '当前',
                            style: TextStyle(
                              color: FrostColors.accentIce,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FrostButton(
              label: '新建账本',
              expanded: true,
              onPressed: () => _create(context),
            ),
            if (state.ledgers.length > 1) ...[
              const SizedBox(height: 8),
              FrostButton(
                label: '删除当前账本',
                danger: true,
                expanded: true,
                onPressed: () async {
                  final ok = await showFrostConfirm(
                    context,
                    title: '删除账本',
                    message: '将删除当前账本的流水、霜匣与分类，不可恢复。',
                    confirmLabel: '确认删除',
                  );
                  if (ok && context.mounted) {
                    await context.read<AppState>().deleteActiveLedger();
                    if (context.mounted) {
                      showFrostToast(context, '已删除');
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    var persona = LedgerPersona.general;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: Colors.transparent,
          child: FrostPanel(
            title: '新建账本',
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '账本名称',
                      hintText: '如：校园账 / 工资账',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: balCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    decoration: const InputDecoration(
                      labelText: '初始余额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('人群分类', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  for (final p in LedgerPersona.values)
                    RadioListTile<LedgerPersona>(
                      dense: true,
                      value: p,
                      groupValue: persona,
                      activeColor: FrostColors.accentIce,
                      title: Text(PersonaPresets.label(p)),
                      subtitle: Text(
                        PersonaPresets.subtitle(p),
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: (v) => setLocal(() => persona = v!),
                    ),
                  const SizedBox(height: 8),
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
                          label: '创建',
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

    if (ok == true && context.mounted) {
      final name = nameCtrl.text.trim().isEmpty
          ? PersonaPresets.defaultLedgerName(persona)
          : nameCtrl.text.trim();
      final bal = double.tryParse(balCtrl.text.trim()) ?? 0;
      await context.read<AppState>().createLedgerBook(
            name: name,
            persona: persona,
            initialBalance: bal,
          );
      if (context.mounted) showFrostToast(context, '账本已创建');
    }
  }
}
