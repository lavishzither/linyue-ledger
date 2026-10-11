enum TxType { expense, income }

enum PiggyDirection { into, outOf }

enum BudgetScope { total, category }

enum LedgerPersona { student, worker, freelancer, general }

enum PiggyScale { big, small }

enum FundKind { wechat, alipay, bank, cash, custom }

class FundAccount {
  final int? id;
  final int ledgerId;
  final String name;
  final FundKind kind;
  /// 该账户计入的初始/底仓金额
  final double balance;
  final String iconKey;
  final int sort;
  final bool isPreset;

  const FundAccount({
    this.id,
    required this.ledgerId,
    required this.name,
    required this.kind,
    this.balance = 0,
    required this.iconKey,
    this.sort = 0,
    this.isPreset = false,
  });

  FundAccount copyWith({
    int? id,
    int? ledgerId,
    String? name,
    FundKind? kind,
    double? balance,
    String? iconKey,
    int? sort,
    bool? isPreset,
  }) {
    return FundAccount(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      balance: balance ?? this.balance,
      iconKey: iconKey ?? this.iconKey,
      sort: sort ?? this.sort,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'name': name,
        'kind': kind.name,
        'balance': balance,
        'icon_key': iconKey,
        'sort': sort,
        'is_preset': isPreset ? 1 : 0,
      };

  factory FundAccount.fromMap(Map<String, Object?> m) => FundAccount(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int,
        name: m['name'] as String,
        kind: FundKind.values.firstWhere(
          (e) => e.name == m['kind'],
          orElse: () => FundKind.custom,
        ),
        balance: (m['balance'] as num?)?.toDouble() ?? 0,
        iconKey: m['icon_key'] as String? ?? 'wallet',
        sort: m['sort'] as int? ?? 0,
        isPreset: (m['is_preset'] as int? ?? 0) == 1,
      );

  static List<FundAccount> presetSeeds(int ledgerId, {double cashBalance = 0}) {
    return [
      FundAccount(
        ledgerId: ledgerId,
        name: '微信',
        kind: FundKind.wechat,
        balance: 0,
        iconKey: 'wechat',
        sort: 0,
        isPreset: true,
      ),
      FundAccount(
        ledgerId: ledgerId,
        name: '支付宝',
        kind: FundKind.alipay,
        balance: 0,
        iconKey: 'alipay',
        sort: 1,
        isPreset: true,
      ),
      FundAccount(
        ledgerId: ledgerId,
        name: '银行卡',
        kind: FundKind.bank,
        balance: 0,
        iconKey: 'bank',
        sort: 2,
        isPreset: true,
      ),
      FundAccount(
        ledgerId: ledgerId,
        name: '现金',
        kind: FundKind.cash,
        balance: cashBalance,
        iconKey: 'cash',
        sort: 3,
        isPreset: true,
      ),
    ];
  }
}

class LedgerBook {
  final int? id;
  final String name;
  final LedgerPersona persona;
  final double initialBalance;
  final DateTime createdAt;

  const LedgerBook({
    this.id,
    required this.name,
    required this.persona,
    this.initialBalance = 0,
    required this.createdAt,
  });

  LedgerBook copyWith({
    int? id,
    String? name,
    LedgerPersona? persona,
    double? initialBalance,
    DateTime? createdAt,
  }) {
    return LedgerBook(
      id: id ?? this.id,
      name: name ?? this.name,
      persona: persona ?? this.persona,
      initialBalance: initialBalance ?? this.initialBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'persona': persona.name,
        'initial_balance': initialBalance,
        'created_at': createdAt.toIso8601String(),
      };

  factory LedgerBook.fromMap(Map<String, Object?> m) => LedgerBook(
        id: m['id'] as int?,
        name: m['name'] as String,
        persona: LedgerPersona.values.firstWhere(
          (e) => e.name == m['persona'],
          orElse: () => LedgerPersona.general,
        ),
        initialBalance: (m['initial_balance'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class Category {
  final int? id;
  final int ledgerId;
  final String name;
  final TxType type;
  final String iconKey;
  final int sort;
  final bool isSystem;

  const Category({
    this.id,
    required this.ledgerId,
    required this.name,
    required this.type,
    required this.iconKey,
    this.sort = 0,
    this.isSystem = true,
  });

  Category copyWith({
    int? id,
    int? ledgerId,
    String? name,
    TxType? type,
    String? iconKey,
    int? sort,
    bool? isSystem,
  }) {
    return Category(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      sort: sort ?? this.sort,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'name': name,
        'type': type.name,
        'icon_key': iconKey,
        'sort': sort,
        'is_system': isSystem ? 1 : 0,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int? ?? 1,
        name: m['name'] as String,
        type: (m['type'] as String) == 'income' ? TxType.income : TxType.expense,
        iconKey: m['icon_key'] as String,
        sort: m['sort'] as int? ?? 0,
        isSystem: (m['is_system'] as int? ?? 1) == 1,
      );
}

class Transaction {
  final int? id;
  final int ledgerId;
  final TxType type;
  final double amount;
  final int categoryId;
  /// 关联资金账户；旧数据可能为空
  final int? fundAccountId;
  final String note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.fundAccountId,
    this.note = '',
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Transaction copyWith({
    int? id,
    int? ledgerId,
    TxType? type,
    double? amount,
    int? categoryId,
    int? fundAccountId,
    String? note,
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearFundAccount = false,
  }) {
    return Transaction(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      fundAccountId:
          clearFundAccount ? null : (fundAccountId ?? this.fundAccountId),
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'type': type.name,
        'amount': amount,
        'category_id': categoryId,
        'fund_account_id': fundAccountId,
        'note': note,
        'occurred_at': occurredAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Transaction.fromMap(Map<String, Object?> m) => Transaction(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int? ?? 1,
        type: (m['type'] as String) == 'income' ? TxType.income : TxType.expense,
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['category_id'] as int,
        fundAccountId: m['fund_account_id'] as int?,
        note: m['note'] as String? ?? '',
        occurredAt: DateTime.parse(m['occurred_at'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

class PiggyBank {
  final int? id;
  final int ledgerId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  /// 每月小目标金额；0 表示未设置
  final double monthlyTarget;
  final PiggyScale scale;
  final String note;
  final String coverColor;
  final DateTime createdAt;
  final DateTime? achievedAt;
  /// 目标完成日（倒计时用）
  final DateTime? targetDate;

  const PiggyBank({
    this.id,
    required this.ledgerId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.monthlyTarget = 0,
    this.scale = PiggyScale.small,
    this.note = '',
    this.coverColor = '#7EB6D4',
    required this.createdAt,
    this.achievedAt,
    this.targetDate,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 999);

  bool get isBig => scale == PiggyScale.big;

  bool get hasMonthlyTarget => monthlyTarget > 0;

  int? get daysLeft {
    if (targetDate == null) return null;
    final today = DateTime.now();
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return b.difference(a).inDays;
  }

  PiggyBank copyWith({
    int? id,
    int? ledgerId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    double? monthlyTarget,
    PiggyScale? scale,
    String? note,
    String? coverColor,
    DateTime? createdAt,
    DateTime? achievedAt,
    DateTime? targetDate,
    bool clearAchieved = false,
    bool clearTargetDate = false,
  }) {
    return PiggyBank(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      scale: scale ?? this.scale,
      note: note ?? this.note,
      coverColor: coverColor ?? this.coverColor,
      createdAt: createdAt ?? this.createdAt,
      achievedAt: clearAchieved ? null : (achievedAt ?? this.achievedAt),
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'monthly_target': monthlyTarget,
        'task_scale': scale.name,
        'note': note,
        'cover_color': coverColor,
        'created_at': createdAt.toIso8601String(),
        'achieved_at': achievedAt?.toIso8601String(),
        'target_date': targetDate?.toIso8601String(),
      };

  factory PiggyBank.fromMap(Map<String, Object?> m) => PiggyBank(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int? ?? 1,
        name: m['name'] as String,
        targetAmount: (m['target_amount'] as num).toDouble(),
        currentAmount: (m['current_amount'] as num).toDouble(),
        monthlyTarget: (m['monthly_target'] as num?)?.toDouble() ?? 0,
        scale: (m['task_scale'] as String?) == 'big' ? PiggyScale.big : PiggyScale.small,
        note: m['note'] as String? ?? '',
        coverColor: m['cover_color'] as String? ?? '#7EB6D4',
        createdAt: DateTime.parse(m['created_at'] as String),
        achievedAt: m['achieved_at'] == null
            ? null
            : DateTime.parse(m['achieved_at'] as String),
        targetDate: m['target_date'] == null
            ? null
            : DateTime.tryParse(m['target_date'] as String),
      );
}

class QuickTemplate {
  final int? id;
  final int ledgerId;
  final String title;
  final TxType type;
  final double amount;
  final int categoryId;
  final String note;
  final int sort;

  const QuickTemplate({
    this.id,
    required this.ledgerId,
    required this.title,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.note = '',
    this.sort = 0,
  });

  QuickTemplate copyWith({
    int? id,
    int? ledgerId,
    String? title,
    TxType? type,
    double? amount,
    int? categoryId,
    String? note,
    int? sort,
  }) {
    return QuickTemplate(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      title: title ?? this.title,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      sort: sort ?? this.sort,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'title': title,
        'type': type.name,
        'amount': amount,
        'category_id': categoryId,
        'note': note,
        'sort': sort,
      };

  factory QuickTemplate.fromMap(Map<String, Object?> m) => QuickTemplate(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int,
        title: m['title'] as String,
        type: (m['type'] as String) == 'income' ? TxType.income : TxType.expense,
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['category_id'] as int,
        note: m['note'] as String? ?? '',
        sort: m['sort'] as int? ?? 0,
      );
}

class PiggyTransfer {
  final int? id;
  final int piggyId;
  final PiggyDirection direction;
  final double amount;
  final DateTime occurredAt;
  final String? note;

  const PiggyTransfer({
    this.id,
    required this.piggyId,
    required this.direction,
    required this.amount,
    required this.occurredAt,
    this.note,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'piggy_id': piggyId,
        'direction': direction == PiggyDirection.into ? 'in' : 'out',
        'amount': amount,
        'occurred_at': occurredAt.toIso8601String(),
        'note': note,
      };

  factory PiggyTransfer.fromMap(Map<String, Object?> m) => PiggyTransfer(
        id: m['id'] as int?,
        piggyId: m['piggy_id'] as int,
        direction: (m['direction'] as String) == 'in'
            ? PiggyDirection.into
            : PiggyDirection.outOf,
        amount: (m['amount'] as num).toDouble(),
        occurredAt: DateTime.parse(m['occurred_at'] as String),
        note: m['note'] as String?,
      );
}

class Budget {
  final int? id;
  final int ledgerId;
  final String month;
  final BudgetScope scope;
  final int? categoryId;
  final double amount;

  const Budget({
    this.id,
    required this.ledgerId,
    required this.month,
    required this.scope,
    this.categoryId,
    required this.amount,
  });

  Budget copyWith({
    int? id,
    int? ledgerId,
    String? month,
    BudgetScope? scope,
    int? categoryId,
    double? amount,
  }) {
    return Budget(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      month: month ?? this.month,
      scope: scope ?? this.scope,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ledger_id': ledgerId,
        'month': month,
        'scope': scope.name,
        'category_id': categoryId,
        'amount': amount,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int?,
        ledgerId: m['ledger_id'] as int? ?? 1,
        month: m['month'] as String,
        scope: (m['scope'] as String) == 'category'
            ? BudgetScope.category
            : BudgetScope.total,
        categoryId: m['category_id'] as int?,
        amount: (m['amount'] as num).toDouble(),
      );
}

class AppSettings {
  final bool onboarded;
  final bool budgetEnabled;
  final int? activeLedgerId;

  const AppSettings({
    this.onboarded = false,
    this.budgetEnabled = false,
    this.activeLedgerId,
  });

  AppSettings copyWith({
    bool? onboarded,
    bool? budgetEnabled,
    int? activeLedgerId,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      budgetEnabled: budgetEnabled ?? this.budgetEnabled,
      activeLedgerId: activeLedgerId ?? this.activeLedgerId,
    );
  }
}
