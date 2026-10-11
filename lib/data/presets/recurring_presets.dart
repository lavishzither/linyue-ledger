enum RecurringPeriod { monthly, yearly }

extension RecurringPeriodX on RecurringPeriod {
  String get label => this == RecurringPeriod.monthly ? '每月' : '每年';

  static RecurringPeriod fromName(String? n) =>
      n == 'yearly' ? RecurringPeriod.yearly : RecurringPeriod.monthly;
}

/// 市面常见自动续费模板（金额为常见参考价，可改）
class RecurringPreset {
  final String key;
  final String title;
  final double amount;
  final RecurringPeriod period;
  final String iconKey;
  final String hint;

  const RecurringPreset({
    required this.key,
    required this.title,
    required this.amount,
    required this.period,
    required this.iconKey,
    this.hint = '',
  });
}

class RecurringPresets {
  static const List<RecurringPreset> all = [
    // —— 视频 ——
    RecurringPreset(
      key: 'bilibili_year',
      title: 'B站大会员',
      amount: 148,
      period: RecurringPeriod.yearly,
      iconKey: 'movie',
      hint: '年卡常见价',
    ),
    RecurringPreset(
      key: 'bilibili_month',
      title: 'B站大会员',
      amount: 25,
      period: RecurringPeriod.monthly,
      iconKey: 'movie',
      hint: '月卡',
    ),
    RecurringPreset(
      key: 'iqiyi_month',
      title: '爱奇艺黄金会员',
      amount: 30,
      period: RecurringPeriod.monthly,
      iconKey: 'movie',
    ),
    RecurringPreset(
      key: 'iqiyi_year',
      title: '爱奇艺黄金会员',
      amount: 198,
      period: RecurringPeriod.yearly,
      iconKey: 'movie',
    ),
    RecurringPreset(
      key: 'tencent_video_month',
      title: '腾讯视频 VIP',
      amount: 30,
      period: RecurringPeriod.monthly,
      iconKey: 'movie',
    ),
    RecurringPreset(
      key: 'tencent_video_year',
      title: '腾讯视频 VIP',
      amount: 198,
      period: RecurringPeriod.yearly,
      iconKey: 'movie',
    ),
    RecurringPreset(
      key: 'youku_month',
      title: '优酷 VIP',
      amount: 30,
      period: RecurringPeriod.monthly,
      iconKey: 'movie',
    ),
    RecurringPreset(
      key: 'mgtv_month',
      title: '芒果TV会员',
      amount: 30,
      period: RecurringPeriod.monthly,
      iconKey: 'movie',
    ),
    RecurringPreset(
      key: 'disney_month',
      title: 'Disney+ / 迪士尼',
      amount: 48,
      period: RecurringPeriod.monthly,
      iconKey: 'movie',
    ),
    // —— 音乐 ——
    RecurringPreset(
      key: 'netease_month',
      title: '网易云音乐会员',
      amount: 18,
      period: RecurringPeriod.monthly,
      iconKey: 'music',
    ),
    RecurringPreset(
      key: 'netease_year',
      title: '网易云音乐会员',
      amount: 88,
      period: RecurringPeriod.yearly,
      iconKey: 'music',
    ),
    RecurringPreset(
      key: 'qqmusic_month',
      title: 'QQ音乐绿钻',
      amount: 15,
      period: RecurringPeriod.monthly,
      iconKey: 'music',
    ),
    RecurringPreset(
      key: 'qqmusic_year',
      title: 'QQ音乐绿钻',
      amount: 180,
      period: RecurringPeriod.yearly,
      iconKey: 'music',
    ),
    RecurringPreset(
      key: 'apple_music_month',
      title: 'Apple Music',
      amount: 11,
      period: RecurringPeriod.monthly,
      iconKey: 'music',
      hint: '学生价约 ¥6',
    ),
    RecurringPreset(
      key: 'spotify_month',
      title: 'Spotify',
      amount: 15,
      period: RecurringPeriod.monthly,
      iconKey: 'music',
    ),
    RecurringPreset(
      key: 'kugou_month',
      title: '酷狗音乐会员',
      amount: 15,
      period: RecurringPeriod.monthly,
      iconKey: 'music',
    ),
    // —— 电商 / 生活 ——
    RecurringPreset(
      key: 'jd_plus_year',
      title: '京东 PLUS',
      amount: 149,
      period: RecurringPeriod.yearly,
      iconKey: 'cart',
    ),
    RecurringPreset(
      key: 'tmall_88vip_year',
      title: '淘宝 88VIP',
      amount: 88,
      period: RecurringPeriod.yearly,
      iconKey: 'shop',
    ),
    RecurringPreset(
      key: 'meituan_month',
      title: '美团会员',
      amount: 15,
      period: RecurringPeriod.monthly,
      iconKey: 'food',
    ),
    RecurringPreset(
      key: 'eleme_month',
      title: '饿了么超级吃货卡',
      amount: 15,
      period: RecurringPeriod.monthly,
      iconKey: 'food',
    ),
    RecurringPreset(
      key: 'didi_month',
      title: '滴滴会员',
      amount: 18,
      period: RecurringPeriod.monthly,
      iconKey: 'taxi',
    ),
    // —— 云盘 / 办公 ——
    RecurringPreset(
      key: 'icloud_month',
      title: 'iCloud+',
      amount: 6,
      period: RecurringPeriod.monthly,
      iconKey: 'cloud',
      hint: '50GB',
    ),
    RecurringPreset(
      key: 'baidu_pan_month',
      title: '百度网盘超级会员',
      amount: 25,
      period: RecurringPeriod.monthly,
      iconKey: 'cloud',
    ),
    RecurringPreset(
      key: 'aliyun_drive_month',
      title: '阿里云盘会员',
      amount: 15,
      period: RecurringPeriod.monthly,
      iconKey: 'cloud',
    ),
    RecurringPreset(
      key: 'wps_month',
      title: 'WPS 会员',
      amount: 15,
      period: RecurringPeriod.monthly,
      iconKey: 'tools',
    ),
    RecurringPreset(
      key: 'xunlei_month',
      title: '迅雷会员',
      amount: 30,
      period: RecurringPeriod.monthly,
      iconKey: 'cloud',
    ),
    // —— 游戏 / 运动 / AI ——
    RecurringPreset(
      key: 'switch_online_year',
      title: 'Switch Online',
      amount: 148,
      period: RecurringPeriod.yearly,
      iconKey: 'game',
    ),
    RecurringPreset(
      key: 'xbox_gamepass_month',
      title: 'Game Pass',
      amount: 35,
      period: RecurringPeriod.monthly,
      iconKey: 'game',
    ),
    RecurringPreset(
      key: 'keep_month',
      title: 'Keep 会员',
      amount: 25,
      period: RecurringPeriod.monthly,
      iconKey: 'fitness',
    ),
    RecurringPreset(
      key: 'chatgpt_month',
      title: 'ChatGPT Plus',
      amount: 148,
      period: RecurringPeriod.monthly,
      iconKey: 'cloud',
      hint: '约 \$20',
    ),
    RecurringPreset(
      key: 'cursor_month',
      title: 'Cursor Pro',
      amount: 148,
      period: RecurringPeriod.monthly,
      iconKey: 'tools',
      hint: '约 \$20',
    ),
    RecurringPreset(
      key: 'notion_month',
      title: 'Notion',
      amount: 70,
      period: RecurringPeriod.monthly,
      iconKey: 'study',
    ),
    RecurringPreset(
      key: 'adobe_month',
      title: 'Adobe 摄影计划',
      amount: 78,
      period: RecurringPeriod.monthly,
      iconKey: 'camera',
    ),
  ];

  static List<RecurringPreset> ofPeriod(RecurringPeriod p) =>
      all.where((e) => e.period == p).toList();
}

class RecurringBill {
  final int? id;
  final int ledgerId;
  final String title;
  final double amount;
  final int categoryId;
  final int? fundAccountId;
  final RecurringPeriod period;
  final DateTime nextDueAt;
  final String note;
  final bool enabled;
  final String? templateKey;
  final DateTime? lastPostedAt;
  final DateTime createdAt;

  const RecurringBill({
    this.id,
    required this.ledgerId,
    required this.title,
    required this.amount,
    required this.categoryId,
    this.fundAccountId,
    required this.period,
    required this.nextDueAt,
    this.note = '',
    this.enabled = true,
    this.templateKey,
    this.lastPostedAt,
    required this.createdAt,
  });

  RecurringBill copyWith({
    int? id,
    int? ledgerId,
    String? title,
    double? amount,
    int? categoryId,
    int? fundAccountId,
    RecurringPeriod? period,
    DateTime? nextDueAt,
    String? note,
    bool? enabled,
    String? templateKey,
    DateTime? lastPostedAt,
    DateTime? createdAt,
    bool clearFundAccount = false,
    bool clearLastPosted = false,
  }) {
    return RecurringBill(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      fundAccountId:
          clearFundAccount ? null : (fundAccountId ?? this.fundAccountId),
      period: period ?? this.period,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      note: note ?? this.note,
      enabled: enabled ?? this.enabled,
      templateKey: templateKey ?? this.templateKey,
      lastPostedAt:
          clearLastPosted ? null : (lastPostedAt ?? this.lastPostedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'title': title,
        'amount': amount,
        'category_id': categoryId,
        'fund_account_id': fundAccountId,
        'period': period.name,
        'next_due_at': DateTime(nextDueAt.year, nextDueAt.month, nextDueAt.day)
            .toIso8601String(),
        'note': note,
        'enabled': enabled ? 1 : 0,
        'template_key': templateKey,
        'last_posted_at': lastPostedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory RecurringBill.fromMap(Map<String, Object?> m) => RecurringBill(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int,
        title: m['title'] as String,
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['category_id'] as int,
        fundAccountId: m['fund_account_id'] as int?,
        period: RecurringPeriodX.fromName(m['period'] as String?),
        nextDueAt: DateTime.parse(m['next_due_at'] as String),
        note: m['note'] as String? ?? '',
        enabled: (m['enabled'] as int? ?? 1) == 1,
        templateKey: m['template_key'] as String?,
        lastPostedAt: m['last_posted_at'] == null
            ? null
            : DateTime.tryParse(m['last_posted_at'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static DateTime advance(DateTime from, RecurringPeriod period) {
    final d = DateTime(from.year, from.month, from.day);
    if (period == RecurringPeriod.monthly) {
      return DateTime(d.year, d.month + 1, d.day);
    }
    return DateTime(d.year + 1, d.month, d.day);
  }

  int? get daysUntil {
    final today = DateTime.now();
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(nextDueAt.year, nextDueAt.month, nextDueAt.day);
    return b.difference(a).inDays;
  }
}
