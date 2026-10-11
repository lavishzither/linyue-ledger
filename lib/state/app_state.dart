import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../data/presets/persona_presets.dart';
import '../data/presets/recurring_presets.dart';
import '../data/repository.dart';

class AppState extends ChangeNotifier {
  AppState(this._repo);

  final LedgerRepository _repo;

  bool loading = true;
  AppSettings settings = const AppSettings();
  List<LedgerBook> ledgers = [];
  LedgerBook? activeLedger;
  List<Category> categories = [];
  List<Transaction> transactions = [];
  List<PiggyBank> piggies = [];
  List<QuickTemplate> templates = [];
  List<FundAccount> fundAccounts = [];
  List<RecurringBill> recurringBills = [];
  /// 本次打开补记的自动续费笔数
  int lastRecurringPosted = 0;
  /// piggyId -> 本月实际存入
  Map<int, double> piggyMonthDeposits = {};
  /// piggyId -> 近月平均每月存入
  Map<int, double> piggyAvgMonthlyDeposits = {};
  Budget? monthBudget;
  List<Budget> categoryBudgets = [];

  DateTime ledgerMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String ledgerQuery = '';
  TxType? ledgerTypeFilter;
  int? ledgerCategoryFilter;

  int? get activeLedgerId => activeLedger?.id ?? settings.activeLedgerId;

  Future<void> init() async {
    loading = true;
    notifyListeners();
    await reload();
    loading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    settings = await _repo.getSettings();
    ledgers = await _repo.getLedgers();
    final id = settings.activeLedgerId ?? (ledgers.isEmpty ? null : ledgers.first.id);
    if (id != null) {
      activeLedger = await _repo.getLedger(id) ?? (ledgers.isEmpty ? null : ledgers.first);
      final lid = activeLedger!.id!;
      if (settings.activeLedgerId != lid) {
        settings = settings.copyWith(activeLedgerId: lid);
        await _repo.saveSettings(settings);
      }
      categories = await _repo.getCategories(lid);
      transactions = await _repo.getTransactions(lid);
      piggies = await _repo.getPiggies(lid);
      templates = await _repo.getTemplates(lid);
      fundAccounts = await _repo.getFundAccounts(lid);
      lastRecurringPosted = await _repo.processDueRecurring(lid);
      if (lastRecurringPosted > 0) {
        transactions = await _repo.getTransactions(lid);
      }
      recurringBills = await _repo.getRecurringBills(lid);
      await _reloadPiggyMonthDeposits();
      final monthKey = LedgerRepository.monthKey(DateTime.now());
      monthBudget = await _repo.getTotalBudget(lid, monthKey);
      categoryBudgets = await _repo.getCategoryBudgets(lid, monthKey);
    } else {
      activeLedger = null;
      categories = [];
      transactions = [];
      piggies = [];
      templates = [];
      fundAccounts = [];
      recurringBills = [];
      lastRecurringPosted = 0;
      piggyMonthDeposits = {};
      piggyAvgMonthlyDeposits = {};
      monthBudget = null;
      categoryBudgets = [];
    }
    notifyListeners();
  }

  List<RecurringBill> get upcomingRecurring {
    final list = recurringBills.where((b) => b.enabled).toList()
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    return list.take(5).toList();
  }

  /// 确保有「订阅」支出分类，供自动续费使用
  Future<int> ensureSubscriptionCategoryId() async {
    final lid = activeLedgerId;
    if (lid == null) throw StateError('无账本');
    for (final name in ['订阅', '会员', '娱乐']) {
      for (final c in categories) {
        if (c.type == TxType.expense && c.name == name && c.id != null) {
          return c.id!;
        }
      }
    }
    await addCustomCategory(
      name: '订阅',
      type: TxType.expense,
      iconKey: 'sub',
    );
    final created = categories.where((c) => c.name == '订阅' && c.type == TxType.expense);
    return created.first.id!;
  }

  Future<void> saveRecurringBill(RecurringBill b) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.upsertRecurringBill(b.copyWith(ledgerId: lid));
    recurringBills = await _repo.getRecurringBills(lid);
    notifyListeners();
  }

  Future<void> removeRecurringBill(int id) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.deleteRecurringBill(id);
    recurringBills = await _repo.getRecurringBills(lid);
    notifyListeners();
  }

  Future<void> toggleRecurringBill(RecurringBill b, bool enabled) async {
    await saveRecurringBill(b.copyWith(enabled: enabled));
  }

  Category? categoryById(int id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Category> categoriesOf(TxType type) =>
      categories.where((c) => c.type == type).toList();

  List<PiggyBank> get bigPiggies =>
      piggies.where((p) => p.scale == PiggyScale.big).toList();

  List<PiggyBank> get smallPiggies =>
      piggies.where((p) => p.scale == PiggyScale.small).toList();

  double get piggyTotal =>
      piggies.fold(0.0, (s, p) => s + p.currentAmount);

  /// 各资金账户底仓合计（兼容旧账本 initial_balance）
  double get fundBaseTotal {
    final fromAccounts = fundAccounts.fold(0.0, (s, a) => s + a.balance);
    if (fundAccounts.isNotEmpty) return fromAccounts;
    return activeLedger?.initialBalance ?? 0;
  }

  FundAccount? fundAccountById(int? id) {
    if (id == null) return null;
    for (final a in fundAccounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  FundAccount? get defaultFundAccount {
    for (final a in fundAccounts) {
      if (a.kind == FundKind.cash) return a;
    }
    return fundAccounts.isEmpty ? null : fundAccounts.first;
  }

  /// 账户当前余额 = 底仓 + 该账户收入 − 该账户支出
  double accountEffectiveBalance(FundAccount a) {
    if (a.id == null) return a.balance;
    var delta = 0.0;
    for (final t in transactions) {
      if (t.fundAccountId != a.id) continue;
      delta += t.type == TxType.income ? t.amount : -t.amount;
    }
    return a.balance + delta;
  }

  double get availableBalance {
    if (fundAccounts.isNotEmpty) {
      final sum = fundAccounts.fold(0.0, (s, a) => s + accountEffectiveBalance(a));
      return sum - piggyTotal;
    }
    final income = transactions
        .where((t) => t.type == TxType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == TxType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    return fundBaseTotal + income - expense - piggyTotal;
  }

  double get netWorth => availableBalance + piggyTotal;

  List<Transaction> get recentFive {
    final list = [...transactions]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return list.take(5).toList();
  }

  List<Transaction> transactionsInMonth(DateTime month) {
    return transactions.where((t) {
      return t.occurredAt.year == month.year && t.occurredAt.month == month.month;
    }).toList();
  }

  double monthExpense([DateTime? month]) {
    final m = month ?? DateTime.now();
    return transactionsInMonth(m)
        .where((t) => t.type == TxType.expense)
        .fold(0.0, (s, t) => s + t.amount);
  }

  double monthIncome([DateTime? month]) {
    final m = month ?? DateTime.now();
    return transactionsInMonth(m)
        .where((t) => t.type == TxType.income)
        .fold(0.0, (s, t) => s + t.amount);
  }

  List<Transaction> get filteredLedger {
    return transactions.where((t) {
      if (t.occurredAt.year != ledgerMonth.year ||
          t.occurredAt.month != ledgerMonth.month) {
        return false;
      }
      if (ledgerTypeFilter != null && t.type != ledgerTypeFilter) return false;
      if (ledgerCategoryFilter != null && t.categoryId != ledgerCategoryFilter) {
        return false;
      }
      if (ledgerQuery.trim().isNotEmpty) {
        final q = ledgerQuery.trim().toLowerCase();
        final noteOk = t.note.toLowerCase().contains(q);
        final amountOk = t.amount.toString().contains(q);
        if (!noteOk && !amountOk) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  Map<DateTime, List<Transaction>> get ledgerGrouped {
    final map = <DateTime, List<Transaction>>{};
    for (final t in filteredLedger) {
      final day = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
      map.putIfAbsent(day, () => []).add(t);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  Map<int, double> expenseByCategory({
    required DateTime from,
    required DateTime to,
  }) {
    final map = <int, double>{};
    for (final t in transactions) {
      if (t.type != TxType.expense) continue;
      if (t.occurredAt.isBefore(from) || !t.occurredAt.isBefore(to)) continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
    }
    return map;
  }

  List<({DateTime month, double expense})> last6MonthExpenses() {
    final now = DateTime.now();
    final list = <({DateTime month, double expense})>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      list.add((month: m, expense: monthExpense(m)));
    }
    return list;
  }

  List<String> anomalyHints(DateTime month) {
    final prev = DateTime(month.year, month.month - 1);
    final curMap = expenseByCategory(
      from: DateTime(month.year, month.month, 1),
      to: DateTime(month.year, month.month + 1, 1),
    );
    final prevMap = expenseByCategory(
      from: DateTime(prev.year, prev.month, 1),
      to: DateTime(prev.year, prev.month + 1, 1),
    );
    final hints = <String>[];
    for (final e in curMap.entries) {
      final prevAmt = prevMap[e.key] ?? 0;
      final diff = e.value - prevAmt;
      if (prevAmt <= 0) continue;
      final ratio = diff / prevAmt;
      if (ratio > 0.3 && diff >= 50) {
        final name = categoryById(e.key)?.name ?? '某分类';
        hints.add('$name较上月偏高');
      }
    }
    return hints;
  }

  Future<void> completeOnboarding({
    required double initial,
    required LedgerPersona persona,
  }) async {
    await _repo.onboard(persona: persona, initialBalance: initial);
    await reload();
  }

  Future<void> switchLedger(int ledgerId) async {
    settings = settings.copyWith(activeLedgerId: ledgerId);
    await _repo.saveSettings(settings);
    await reload();
  }

  Future<void> createLedgerBook({
    required String name,
    required LedgerPersona persona,
    double initialBalance = 0,
    bool switchTo = true,
  }) async {
    final id = await _repo.createLedger(
      name: name,
      persona: persona,
      initialBalance: initialBalance,
    );
    if (switchTo) {
      await switchLedger(id);
    } else {
      await reload();
    }
  }

  Future<void> updateInitialBalance(double v) async {
    // 兼容旧入口：写入「现金」账户
    final lid = activeLedgerId;
    if (lid == null) return;
    FundAccount? cash;
    for (final a in fundAccounts) {
      if (a.kind == FundKind.cash) {
        cash = a;
        break;
      }
    }
    if (cash != null) {
      await saveFundAccount(cash.copyWith(balance: v));
    } else {
      await saveFundAccount(
        FundAccount(
          ledgerId: lid,
          name: '现金',
          kind: FundKind.cash,
          balance: v,
          iconKey: 'cash',
          isPreset: true,
        ),
      );
    }
  }

  Future<void> saveFundAccount(FundAccount a) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.upsertFundAccount(a.copyWith(ledgerId: lid));
    fundAccounts = await _repo.getFundAccounts(lid);
    notifyListeners();
  }

  Future<String?> removeFundAccount(FundAccount a) async {
    final lid = activeLedgerId;
    if (lid == null || a.id == null) return '无账本';
    if (a.isPreset) return '预设账户不能删除，可把余额改为 0';
    await _repo.deleteFundAccount(a.id!);
    fundAccounts = await _repo.getFundAccounts(lid);
    notifyListeners();
    return null;
  }

  Future<void> setBudgetEnabled(bool enabled) async {
    settings = settings.copyWith(budgetEnabled: enabled);
    await _repo.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setMonthBudgetAmount(double amount) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    final key = LedgerRepository.monthKey(DateTime.now());
    await _repo.setTotalBudget(lid, key, amount);
    monthBudget = await _repo.getTotalBudget(lid, key);
    if (amount > 0 && !settings.budgetEnabled) {
      settings = settings.copyWith(budgetEnabled: true);
      await _repo.saveSettings(settings);
    }
    notifyListeners();
  }

  bool get budgetActive =>
      settings.budgetEnabled && (monthBudget?.amount ?? 0) > 0;

  double get budgetLimit => monthBudget?.amount ?? 0;

  double get budgetUsed => monthExpense();

  double get budgetLeft => budgetLimit - budgetUsed;

  double categoryMonthExpense(int categoryId, [DateTime? month]) {
    final m = month ?? DateTime.now();
    return transactionsInMonth(m)
        .where((t) => t.type == TxType.expense && t.categoryId == categoryId)
        .fold(0.0, (s, t) => s + t.amount);
  }

  Future<void> setCategoryBudgetAmount(int categoryId, double amount) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    final key = LedgerRepository.monthKey(DateTime.now());
    if (amount <= 0) {
      final existing = categoryBudgets.where((b) => b.categoryId == categoryId);
      for (final b in existing) {
        if (b.id != null) await _repo.deleteBudget(b.id!);
      }
    } else {
      await _repo.setCategoryBudget(
        ledgerId: lid,
        month: key,
        categoryId: categoryId,
        amount: amount,
      );
      if (!settings.budgetEnabled) {
        settings = settings.copyWith(budgetEnabled: true);
        await _repo.saveSettings(settings);
      }
    }
    categoryBudgets = await _repo.getCategoryBudgets(lid, key);
    notifyListeners();
  }

  Future<void> removeCategoryBudget(int budgetId) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.deleteBudget(budgetId);
    categoryBudgets = await _repo.getCategoryBudgets(
      lid,
      LedgerRepository.monthKey(DateTime.now()),
    );
    notifyListeners();
  }

  Future<void> saveTransaction(Transaction tx) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    final withLedger = tx.copyWith(ledgerId: lid);
    await _repo.upsertTransaction(withLedger);
    transactions = await _repo.getTransactions(lid);
    notifyListeners();
  }

  Future<void> removeTransaction(int id) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.deleteTransaction(id);
    transactions = await _repo.getTransactions(lid);
    notifyListeners();
  }

  Future<void> _reloadPiggyMonthDeposits() async {
    final now = DateTime.now();
    final map = <int, double>{};
    final avg = <int, double>{};
    for (final p in piggies) {
      if (p.id == null) continue;
      map[p.id!] = await _repo.monthDepositIn(p.id!, now);
      avg[p.id!] = await _repo.avgMonthlyDepositIn(p.id!);
    }
    piggyMonthDeposits = map;
    piggyAvgMonthlyDeposits = avg;
  }

  double monthDepositOf(int piggyId) => piggyMonthDeposits[piggyId] ?? 0;

  double avgMonthlyDepositOf(int piggyId) =>
      piggyAvgMonthlyDeposits[piggyId] ?? 0;

  /// 霜匣倒计时与速度文案
  String? piggyCountdownHint(PiggyBank p) {
    if (p.id == null) return null;
    final remain = p.targetAmount - p.currentAmount;
    if (remain <= 0) return '已满额';
    final days = p.daysLeft;
    final avg = avgMonthlyDepositOf(p.id!);
    if (days == null) {
      if (avg <= 0) return null;
      final months = (remain / avg).ceil();
      return '按近况约 $months 个月可满';
    }
    if (days < 0) return '目标日已过 · 还差 ¥ ${money(remain)}';
    if (days == 0) return '今天截止 · 还差 ¥ ${money(remain)}';
    final needPerDay = remain / days;
    final needPerMonth = needPerDay * 30;
    final buf = StringBuffer('剩 $days 天 · 日均需 ¥ ${money(needPerDay)}');
    if (avg > 0) {
      final paceMonths = remain / avg;
      final ok = paceMonths * 30 <= days + 0.5;
      buf.write(ok ? ' · 进度够用' : ' · 需加快');
    } else {
      buf.write(' · 月均约 ¥ ${money(needPerMonth)}');
    }
    return buf.toString();
  }

  /// 本周一 00:00
  static DateTime weekStart([DateTime? of]) {
    final d = of ?? DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  List<Transaction> transactionsInRange(DateTime from, DateTime to) {
    return transactions.where((t) {
      return !t.occurredAt.isBefore(from) && t.occurredAt.isBefore(to);
    }).toList();
  }

  ({
    double expense,
    double income,
    String? topCategory,
    double? vsLastWeekPct,
  }) weekSummary() {
    final start = weekStart();
    final end = start.add(const Duration(days: 7));
    final prevStart = start.subtract(const Duration(days: 7));
    final cur = transactionsInRange(start, end);
    final prev = transactionsInRange(prevStart, start);
    final expense = cur
        .where((t) => t.type == TxType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final income = cur
        .where((t) => t.type == TxType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final prevExp = prev
        .where((t) => t.type == TxType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final byCat = <int, double>{};
    for (final t in cur.where((t) => t.type == TxType.expense)) {
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    String? top;
    if (byCat.isNotEmpty) {
      final best = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b);
      top = categoryById(best.key)?.name;
    }
    double? vs;
    if (prevExp > 0) {
      vs = (expense - prevExp) / prevExp * 100;
    }
    return (
      expense: expense,
      income: income,
      topCategory: top,
      vsLastWeekPct: vs,
    );
  }

  Future<void> saveTemplate(QuickTemplate t) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.upsertTemplate(t.copyWith(ledgerId: lid));
    templates = await _repo.getTemplates(lid);
    notifyListeners();
  }

  Future<void> removeTemplate(int id) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.deleteTemplate(id);
    templates = await _repo.getTemplates(lid);
    notifyListeners();
  }

  Future<String?> importBackupJson(Map<String, dynamic> data) async {
    final lid = activeLedgerId;
    if (lid == null) return '无账本';
    final appId = data['app'];
    final known = appId == 'qingshuang_ledger' || appId == 'linyue_ledger';
    if (!known && data['ledger'] == null) {
      return '不是凛月记账备份文件';
    }
    try {
      await _repo.importJsonToLedger(lid, data);
      await reload();
      return null;
    } catch (e) {
      return '导入失败：$e';
    }
  }

  Future<void> savePiggy(PiggyBank piggy) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.upsertPiggy(piggy.copyWith(ledgerId: lid));
    piggies = await _repo.getPiggies(lid);
    await _reloadPiggyMonthDeposits();
    notifyListeners();
  }

  Future<void> removePiggy(PiggyBank piggy) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.deletePiggy(piggy.id!);
    piggies = await _repo.getPiggies(lid);
    await _reloadPiggyMonthDeposits();
    notifyListeners();
  }

  Future<String?> transferPiggy({
    required PiggyBank piggy,
    required PiggyDirection direction,
    required double amount,
  }) async {
    if (amount <= 0) return '尚未填写金额';
    if (direction == PiggyDirection.into && amount > availableBalance + 1e-9) {
      return '数额不足';
    }
    if (direction == PiggyDirection.outOf && amount > piggy.currentAmount + 1e-9) {
      return '霜匣余额不足';
    }
    await _repo.transferPiggy(
      piggy: piggy,
      direction: direction,
      amount: amount,
    );
    final lid = activeLedgerId!;
    piggies = await _repo.getPiggies(lid);
    await _reloadPiggyMonthDeposits();
    notifyListeners();
    return null;
  }

  Future<void> renameCategory(int id, String name) async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.renameCategory(id, name);
    categories = await _repo.getCategories(lid);
    notifyListeners();
  }

  Future<String?> addCustomCategory({
    required String name,
    required TxType type,
    String iconKey = 'other',
  }) async {
    final lid = activeLedgerId;
    if (lid == null) return '无账本';
    final n = name.trim();
    if (n.isEmpty) return '请填写分类名';
    if (categories.any((c) => c.type == type && c.name == n)) {
      return '分类已存在';
    }
    await _repo.addCategory(Category(
      ledgerId: lid,
      name: n,
      type: type,
      iconKey: iconKey,
      isSystem: false,
    ));
    categories = await _repo.getCategories(lid);
    notifyListeners();
    return null;
  }

  Future<String?> removeCategory(int id) async {
    final lid = activeLedgerId;
    if (lid == null) return '无账本';
    try {
      await _repo.deleteCategory(id);
    } on StateError catch (e) {
      return e.message;
    }
    if (ledgerCategoryFilter == id) ledgerCategoryFilter = null;
    categories = await _repo.getCategories(lid);
    notifyListeners();
    return null;
  }

  Future<void> clearAllData() async {
    final lid = activeLedgerId;
    if (lid == null) return;
    await _repo.clearLedgerData(lid);
    await reload();
  }

  Future<void> deleteActiveLedger() async {
    final lid = activeLedgerId;
    if (lid == null || ledgers.length <= 1) return;
    await _repo.deleteLedger(lid);
    final remain = await _repo.getLedgers();
    settings = settings.copyWith(activeLedgerId: remain.first.id);
    await _repo.saveSettings(settings);
    await reload();
  }

  Future<Map<String, dynamic>> exportJson() async {
    final lid = activeLedgerId;
    if (lid == null) return {};
    return _repo.exportJsonMap(lid);
  }

  Future<String> exportCsv() async {
    final lid = activeLedgerId;
    if (lid == null) return '';
    return _repo.exportCsv(lid);
  }

  void setLedgerMonth(DateTime m) {
    ledgerMonth = DateTime(m.year, m.month);
    notifyListeners();
  }

  void setLedgerQuery(String q) {
    ledgerQuery = q;
    notifyListeners();
  }

  void setLedgerTypeFilter(TxType? t) {
    ledgerTypeFilter = t;
    notifyListeners();
  }

  void setLedgerCategoryFilter(int? id) {
    ledgerCategoryFilter = id;
    notifyListeners();
  }

  String personaLabel() =>
      activeLedger == null ? '' : PersonaPresets.label(activeLedger!.persona);

  static String money(double v) {
    final f = NumberFormat('#,##0.00');
    return f.format(v);
  }

  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return '今天';
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    return DateFormat('MM-dd').format(d);
  }

  static String scaleLabel(PiggyScale s) => s == PiggyScale.big ? '大任务' : '小任务';
}
