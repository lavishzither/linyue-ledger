import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../theme/frost_theme.dart';

class FrostPanel extends StatelessWidget {
  const FrostPanel({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: FrostColors.bgPanel,
        border: Border.all(color: FrostColors.border, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: FrostColors.border, width: 2)),
                color: Color(0xFFE8F0F6),
              ),
              child: Text(
                title!,
                style: const TextStyle(
                  color: FrostColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class FrostButton extends StatelessWidget {
  const FrostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.ghost = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool ghost;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bg = ghost
        ? Colors.transparent
        : danger
            ? FrostColors.expense
            : FrostColors.accentIce;
    final fg = ghost
        ? FrostColors.text
        : Colors.white;
    final child = Material(
      color: bg,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: FrostColors.border, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: onPressed == null ? FrostColors.textDim : fg,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

Future<bool> showFrostConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确认删除',
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: FrostPanel(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message, style: const TextStyle(color: FrostColors.text, height: 1.4)),
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
                      label: confirmLabel,
                      danger: danger,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

void showFrostToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: FrostColors.text)),
      backgroundColor: FrostColors.bgPanel,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: FrostColors.border, width: 2),
        borderRadius: BorderRadius.circular(0),
      ),
    ),
  );
}

class FrostProgress extends StatelessWidget {
  const FrostProgress({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) {
        final fill = c.maxWidth * v;
        return Container(
          height: 14,
          decoration: BoxDecoration(
            color: FrostColors.barEmpty,
            border: Border.all(color: FrostColors.border, width: 2),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: fill,
            color: FrostColors.barFill,
          ),
        );
      },
    );
  }
}

class PixelPieChart extends StatefulWidget {
  const PixelPieChart({
    super.key,
    required this.slices,
    this.size = 200,
    this.onSelected,
    this.selectedIndex,
    this.centerLabel,
    this.centerValue,
  });

  final List<({String label, double value, Color color})> slices;
  final double size;
  final ValueChanged<int?>? onSelected;
  final int? selectedIndex;
  final String? centerLabel;
  final String? centerValue;

  @override
  State<PixelPieChart> createState() => _PixelPieChartState();
}

class _PixelPieChartState extends State<PixelPieChart> {
  @override
  Widget build(BuildContext context) {
    final total = widget.slices.fold(0.0, (s, e) => s + e.value);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTapDown: (d) {
              if (total <= 0 || widget.onSelected == null) return;
              final c = Offset(widget.size / 2, widget.size / 2);
              final v = d.localPosition - c;
              var angle = math.atan2(v.dy, v.dx);
              angle = (angle + math.pi / 2 + math.pi * 2) % (math.pi * 2);
              var acc = 0.0;
              for (var i = 0; i < widget.slices.length; i++) {
                final sweep = (widget.slices[i].value / total) * math.pi * 2;
                if (angle >= acc && angle < acc + sweep) {
                  widget.onSelected!(
                    widget.selectedIndex == i ? null : i,
                  );
                  return;
                }
                acc += sweep;
              }
            },
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _PiePainter(
                slices: widget.slices,
                selectedIndex: widget.selectedIndex,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.centerLabel != null)
                Text(
                  widget.centerLabel!,
                  style: const TextStyle(color: FrostColors.textDim, fontSize: 11),
                ),
              if (widget.centerValue != null)
                Text(
                  widget.centerValue!,
                  style: const TextStyle(
                    color: FrostColors.balance,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.slices, this.selectedIndex});

  final List<({String label, double value, Color color})> slices;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0.0, (s, e) => s + e.value);
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: c, radius: r);

    if (total <= 0) {
      final p = Paint()
        ..color = FrostColors.barEmpty
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28;
      canvas.drawCircle(c, r - 14, p);
      return;
    }

    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final sweep = (slices[i].value / total) * math.pi * 2;
      final selected = selectedIndex == i;
      final paint = Paint()
        ..color = slices[i].color
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 34 : 28
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }

    final border = Paint()
      ..color = FrostColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r - 28, border);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => true;
}

/// 可供自定义分类选择的通用图标
class CategoryIcons {
  static const map = <String, IconData>{
    'food': Icons.restaurant,
    'coffee': Icons.local_cafe,
    'transit': Icons.directions_bus,
    'car': Icons.directions_car,
    'bike': Icons.pedal_bike,
    'taxi': Icons.local_taxi,
    'flight': Icons.flight,
    'shop': Icons.shopping_bag,
    'cart': Icons.shopping_cart,
    'clothes': Icons.checkroom,
    'fun': Icons.sports_esports,
    'movie': Icons.movie,
    'music': Icons.music_note,
    'sport': Icons.sports_basketball,
    'pet': Icons.pets,
    'home': Icons.home,
    'rent': Icons.apartment,
    'daily': Icons.cleaning_services,
    'water': Icons.water_drop,
    'electric': Icons.bolt,
    'phone': Icons.smartphone,
    'health': Icons.local_hospital,
    'fitness': Icons.fitness_center,
    'study': Icons.menu_book,
    'school': Icons.school,
    'child': Icons.child_care,
    'salary': Icons.payments,
    'part': Icons.work,
    'gift': Icons.card_giftcard,
    'redpacket': Icons.redeem,
    'invest': Icons.trending_up,
    'bank': Icons.account_balance,
    'wechat': Icons.chat_bubble_outline,
    'alipay': Icons.account_balance_wallet_outlined,
    'cash': Icons.payments_outlined,
    'wallet': Icons.wallet_outlined,
    'card': Icons.credit_card,
    'transfer': Icons.swap_horiz,
    'beauty': Icons.spa,
    'hair': Icons.content_cut,
    'travel': Icons.luggage,
    'hotel': Icons.hotel,
    'camera': Icons.photo_camera,
    'game': Icons.videogame_asset,
    'smoke': Icons.smoking_rooms,
    'drink': Icons.local_bar,
    'fruit': Icons.apple,
    'snack': Icons.cookie,
    'repair': Icons.build,
    'insurance': Icons.health_and_safety,
    'tax': Icons.receipt_long,
    'social': Icons.groups,
    'love': Icons.favorite,
    'baby': Icons.baby_changing_station,
    'elder': Icons.elderly,
    'park': Icons.local_parking,
    'gas': Icons.local_gas_station,
    'sub': Icons.subscriptions,
    'cloud': Icons.cloud,
    'tools': Icons.handyman,
    'other': Icons.more_horiz,
    'other_in': Icons.more_horiz,
    'custom': Icons.add_circle_outline,
  };

  /// 选择器用的图标键（不含占位）
  static List<String> get pickerKeys => map.keys
      .where((k) => k != 'other' && k != 'other_in' && k != 'custom')
      .toList();

  static IconData of(String key) => map[key] ?? Icons.circle;
}

class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({super.key, required this.iconKey, this.size = 36});

  final String iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0F6),
        border: Border.all(color: FrostColors.border, width: 2),
      ),
      child: Icon(
        CategoryIcons.of(iconKey),
        size: size * 0.5,
        color: FrostColors.accentViolet,
      ),
    );
  }
}

/// 创建自定义分类：名称 + 图标选择
Future<({String name, String iconKey})?> showCustomCategoryDialog(
  BuildContext context, {
  required TxType type,
}) async {
  final nameCtrl = TextEditingController();
  var iconKey = CategoryIcons.pickerKeys.first;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 340, maxHeight: maxH),
            child: FrostPanel(
              title: type == TxType.expense ? '自定义支出分类' : '自定义收入分类',
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: '分类名称',
                      hintText: '如：游戏充值、奶茶',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('选择图标', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 168),
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemCount: CategoryIcons.pickerKeys.length,
                      itemBuilder: (context, i) {
                        final key = CategoryIcons.pickerKeys[i];
                        final selected = key == iconKey;
                        return InkWell(
                          onTap: () => setLocal(() => iconKey = key),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? FrostColors.accentIce.withValues(alpha: 0.3)
                                  : const Color(0xFFE8F0F6),
                              border: Border.all(
                                color: selected ? FrostColors.accentIce : FrostColors.border,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              CategoryIcons.of(key),
                              color: FrostColors.accentViolet,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
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
                          label: '创建并选用',
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

  if (ok != true) return null;
  final name = nameCtrl.text.trim();
  if (name.isEmpty) return null;
  return (name: name, iconKey: iconKey);
}

class MistBackground extends StatelessWidget {
  const MistBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FrostColors.bgBase, FrostColors.bgMistEnd, FrostColors.bgBase],
        ),
      ),
      child: child,
    );
  }
}

class OverviewBars extends StatelessWidget {
  const OverviewBars({
    super.key,
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final maxV = math.max(income, expense);
    final scale = maxV <= 0 ? 0.0 : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bar('收入', income, FrostColors.income, maxV, scale),
        const SizedBox(height: 8),
        _bar('支出', expense, FrostColors.expense, maxV, scale),
      ],
    );
  }

  Widget _bar(String label, double value, Color color, double maxV, double scale) {
    final ratio = maxV <= 0 ? 0.0 : value / maxV;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label, style: const TextStyle(color: FrostColors.textDim, fontSize: 12)),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: FrostColors.barEmpty,
              border: Border.all(color: FrostColors.border, width: 1),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: scale == 0 ? 0 : ratio.clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
