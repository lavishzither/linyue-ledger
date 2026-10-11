import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../state/app_state.dart';
import '../core/theme/frost_theme.dart';
import '../core/widgets/frost_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  LedgerPersona _persona = LedgerPersona.general;

  @override
  Widget build(BuildContext context) {
    return MistBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 16),
              const Text(
                '凛月记账',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: FrostColors.balance,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '清冷一页，账目分明',
                style: TextStyle(color: FrostColors.textDim, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FrostPanel(
                title: '使用说明',
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('· 数据仅保存在本机，不会上传', style: TextStyle(height: 1.6)),
                    Text('· 可建多本账本，分类随人群变化', style: TextStyle(height: 1.6)),
                    Text('· 首页点「可用余额」可设微信、支付宝等账户底仓', style: TextStyle(height: 1.6)),
                    Text('· 「记一笔」录入收支，可选账户与分类', style: TextStyle(height: 1.6)),
                    Text('· 霜匣用来存目标；预算可在设置或首页查看', style: TextStyle(height: 1.6)),
                    Text('· 流水可搜索筛选；统计看花销结构', style: TextStyle(height: 1.6)),
                    Text('· 设置里可导出 / 导入备份，换机不丢账', style: TextStyle(height: 1.6)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FrostPanel(
                title: '你是哪一类？',
                child: Column(
                  children: [
                    for (final p in LedgerPersona.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setState(() => _persona = p),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _persona == p
                                  ? FrostColors.accentIce.withValues(alpha: 0.2)
                                  : FrostColors.bgBase,
                              border: Border.all(
                                color: _persona == p
                                    ? FrostColors.accentIce
                                    : FrostColors.border,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  PersonaPresets.label(p),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  PersonaPresets.subtitle(p),
                                  style: const TextStyle(
                                    color: FrostColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FrostButton(
                label: '进入霜衡',
                expanded: true,
                onPressed: () async {
                  await context.read<AppState>().completeOnboarding(
                        initial: 0,
                        persona: _persona,
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
