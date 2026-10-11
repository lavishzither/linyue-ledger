import '../models.dart';

/// 人群账本预设分类（「其他」改为记账页「自定义」入口，故不再预置）
class PersonaPresets {
  static String label(LedgerPersona p) => switch (p) {
        LedgerPersona.student => '大学生',
        LedgerPersona.worker => '上班族',
        LedgerPersona.freelancer => '自由职业',
        LedgerPersona.general => '通用',
      };

  static String subtitle(LedgerPersona p) => switch (p) {
        LedgerPersona.student => '生活费、兼职、食堂外卖…',
        LedgerPersona.worker => '工资、通勤、房租房贷…',
        LedgerPersona.freelancer => '项目款、设备、办公…',
        LedgerPersona.general => '日常收支通用分类',
      };

  /// 系统占位「其他」类，界面中改为「自定义」入口，不直接展示
  static bool isPlaceholderOther(String name) =>
      name == '其他' || name == '其他收入';

  static List<(String name, String icon, TxType type)> categories(LedgerPersona p) {
    switch (p) {
      case LedgerPersona.student:
        return const [
          ('食堂', 'food', TxType.expense),
          ('外卖', 'food', TxType.expense),
          ('交通', 'transit', TxType.expense),
          ('学习资料', 'study', TxType.expense),
          ('社交娱乐', 'fun', TxType.expense),
          ('数码', 'shop', TxType.expense),
          ('日用', 'daily', TxType.expense),
          ('恋爱礼物', 'gift', TxType.expense),
          ('生活费', 'salary', TxType.income),
          ('兼职', 'part', TxType.income),
          ('奖学金', 'invest', TxType.income),
          ('红包', 'gift', TxType.income),
        ];
      case LedgerPersona.worker:
        return const [
          ('餐饮', 'food', TxType.expense),
          ('通勤', 'transit', TxType.expense),
          ('房租房贷', 'home', TxType.expense),
          ('购物', 'shop', TxType.expense),
          ('社交应酬', 'fun', TxType.expense),
          ('子女教育', 'study', TxType.expense),
          ('医疗', 'health', TxType.expense),
          ('日用', 'daily', TxType.expense),
          ('工资', 'salary', TxType.income),
          ('奖金', 'invest', TxType.income),
          ('兼职', 'part', TxType.income),
          ('理财', 'invest', TxType.income),
        ];
      case LedgerPersona.freelancer:
        return const [
          ('餐饮', 'food', TxType.expense),
          ('交通', 'transit', TxType.expense),
          ('设备工具', 'shop', TxType.expense),
          ('办公场地', 'home', TxType.expense),
          ('学习提升', 'study', TxType.expense),
          ('社交', 'fun', TxType.expense),
          ('日用', 'daily', TxType.expense),
          ('医疗', 'health', TxType.expense),
          ('项目款', 'salary', TxType.income),
          ('稿费', 'part', TxType.income),
          ('咨询', 'invest', TxType.income),
        ];
      case LedgerPersona.general:
        return const [
          ('餐饮', 'food', TxType.expense),
          ('交通', 'transit', TxType.expense),
          ('购物', 'shop', TxType.expense),
          ('娱乐', 'fun', TxType.expense),
          ('居住', 'home', TxType.expense),
          ('日用', 'daily', TxType.expense),
          ('医疗', 'health', TxType.expense),
          ('学习', 'study', TxType.expense),
          ('工资', 'salary', TxType.income),
          ('兼职', 'part', TxType.income),
          ('红包', 'gift', TxType.income),
          ('理财', 'invest', TxType.income),
        ];
    }
  }

  static String defaultLedgerName(LedgerPersona p) => '${label(p)}账本';
}
