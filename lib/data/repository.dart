import 'package:intl/intl.dart';

import 'database.dart';
import 'models.dart';
import 'presets/persona_presets.dart';
import 'presets/recurring_presets.dart';

class LedgerRepository {
  final _dbProvider = AppDatabase.instance;

  Future<AppSettings> getSettings() async {
    final db = await _dbProvider.database;
    final rows = await db.query('settings', where: 'id = 1');
    if (rows.isEmpty) return const AppSettings();
    final m = rows.first;
    return AppSettings(
      onboarded: (m['onboarded'] as int? ?? 0) == 1,
      budgetEnabled: (m['budget_enabled'] as int? ?? 0) == 1,
      activeLedgerId: m['active_ledger_id'] as int?,
    );
  }

  Future<void> saveSettings(AppSettings s) async {
    final db = await _dbProvider.database;
    await db.update(
      'settings',
      {
        'onboarded': s.onboarded ? 1 : 0,
        'budget_enabled': s.budgetEnabled ? 1 : 0,
        'active_ledger_id': s.activeLedgerId,
      },
      where: 'id = 1',
    );
  }

  Future<List<LedgerBook>> getLedgers() async {
    final db = await _dbProvider.database;
    final rows = await db.query('ledgers', orderBy: 'id ASC');
    return rows.map(LedgerBook.fromMap).toList();
  }

  Future<LedgerBook?> getLedger(int id) async {
    final db = await _dbProvider.database;
    final rows = await db.query('ledgers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return LedgerBook.fromMap(rows.first);
  }

  Future<int> createLedger({
    required String name,
    required LedgerPersona persona,
    double initialBalance = 0,
  }) async {
    final db = await _dbProvider.database;
    final id = await db.insert(
      'ledgers',
      LedgerBook(
        name: name,
        persona: persona,
        initialBalance: initialBalance,
        createdAt: DateTime.now(),
      ).toMap()
        ..remove('id'),
    );
    await AppDatabase.seedCategoriesForLedger(db, id, persona);
    for (final a in FundAccount.presetSeeds(id, cashBalance: initialBalance)) {
      await db.insert('fund_accounts', a.toMap()..remove('id'));
    }
    if (initialBalance != 0) {
      await db.update(
        'ledgers',
        {'initial_balance': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return id;
  }

  Future<void> updateLedger(LedgerBook book) async {
    final db = await _dbProvider.database;
    await db.update(
      'ledgers',
      book.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> deleteLedger(int id) async {
    final db = await _dbProvider.database;
    final piggies = await db.query('piggy_banks', where: 'ledger_id = ?', whereArgs: [id]);
    for (final p in piggies) {
      await db.delete('piggy_transfers', where: 'piggy_id = ?', whereArgs: [p['id']]);
    }
    await db.delete('piggy_banks', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('transactions', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('budgets', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('quick_templates', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('fund_accounts', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('recurring_bills', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FundAccount>> getFundAccounts(int ledgerId) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'fund_accounts',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: 'sort ASC, id ASC',
    );
    return rows.map(FundAccount.fromMap).toList();
  }

  Future<int> upsertFundAccount(FundAccount a) async {
    final db = await _dbProvider.database;
    if (a.id == null) {
      final rows = await db.rawQuery(
        'SELECT MAX(sort) as m FROM fund_accounts WHERE ledger_id = ?',
        [a.ledgerId],
      );
      final maxSort = (rows.first['m'] as int?) ?? 0;
      return db.insert(
        'fund_accounts',
        a.copyWith(sort: maxSort + 1).toMap()..remove('id'),
      );
    }
    await db.update(
      'fund_accounts',
      a.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [a.id],
    );
    return a.id!;
  }

  Future<void> deleteFundAccount(int id) async {
    final db = await _dbProvider.database;
    await db.delete('fund_accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> getCategories(int ledgerId, {TxType? type}) async {
    final db = await _dbProvider.database;
    final where = <String>['ledger_id = ?'];
    final args = <Object?>[ledgerId];
    if (type != null) {
      where.add('type = ?');
      args.add(type.name);
    }
    final rows = await db.query(
      'categories',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'sort ASC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<void> renameCategory(int id, String name) async {
    final db = await _dbProvider.database;
    await db.update('categories', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addCategory(Category category) async {
    final db = await _dbProvider.database;
    final rows = await db.rawQuery(
      'SELECT MAX(sort) as m FROM categories WHERE ledger_id = ? AND type = ?',
      [category.ledgerId, category.type.name],
    );
    final maxSort = (rows.first['m'] as int?) ?? 0;
    return db.insert(
      'categories',
      category.copyWith(sort: maxSort + 1, isSystem: false).toMap()..remove('id'),
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await _dbProvider.database;
    final used = await db.query(
      'transactions',
      where: 'category_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (used.isNotEmpty) {
      throw StateError('分类仍有流水，无法删除');
    }
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// 某霜匣本月实际转入合计
  Future<double> monthDepositIn(int piggyId, DateTime month) async {
    final db = await _dbProvider.database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM piggy_transfers
      WHERE piggy_id = ? AND direction = 'in'
        AND occurred_at >= ? AND occurred_at < ?
      ''',
      [piggyId, start.toIso8601String(), end.toIso8601String()],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Transaction>> getTransactions(int ledgerId) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'transactions',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<int> upsertTransaction(Transaction tx) async {
    final db = await _dbProvider.database;
    if (tx.id == null) {
      return db.insert('transactions', tx.toMap()..remove('id'));
    }
    await db.update(
      'transactions',
      tx.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
    return tx.id!;
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _dbProvider.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PiggyBank>> getPiggies(int ledgerId) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'piggy_banks',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: "CASE task_scale WHEN 'big' THEN 0 ELSE 1 END, id DESC",
    );
    return rows.map(PiggyBank.fromMap).toList();
  }

  Future<int> upsertPiggy(PiggyBank piggy) async {
    final db = await _dbProvider.database;
    if (piggy.id == null) {
      return db.insert('piggy_banks', piggy.toMap()..remove('id'));
    }
    await db.update(
      'piggy_banks',
      piggy.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [piggy.id],
    );
    return piggy.id!;
  }

  Future<void> deletePiggy(int id) async {
    final db = await _dbProvider.database;
    await db.delete('piggy_transfers', where: 'piggy_id = ?', whereArgs: [id]);
    await db.delete('piggy_banks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> transferPiggy({
    required PiggyBank piggy,
    required PiggyDirection direction,
    required double amount,
  }) async {
    final db = await _dbProvider.database;
    final now = DateTime.now();
    var next = piggy.currentAmount +
        (direction == PiggyDirection.into ? amount : -amount);
    if (next < 0) next = 0;
    DateTime? achieved = piggy.achievedAt;
    if (achieved == null && next >= piggy.targetAmount && piggy.targetAmount > 0) {
      achieved = now;
    }
    await db.insert('piggy_transfers', {
      'piggy_id': piggy.id,
      'direction': direction == PiggyDirection.into ? 'in' : 'out',
      'amount': amount,
      'occurred_at': now.toIso8601String(),
      'note': null,
    });
    await db.update(
      'piggy_banks',
      {
        'current_amount': next,
        'achieved_at': achieved?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [piggy.id],
    );
  }

  Future<List<PiggyTransfer>> getAllTransfers() async {
    final db = await _dbProvider.database;
    final rows = await db.query('piggy_transfers');
    return rows.map(PiggyTransfer.fromMap).toList();
  }

  Future<Budget?> getTotalBudget(int ledgerId, String month) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'budgets',
      where: "ledger_id = ? AND month = ? AND scope = 'total'",
      whereArgs: [ledgerId, month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Budget.fromMap(rows.first);
  }

  Future<void> setTotalBudget(int ledgerId, String month, double amount) async {
    final db = await _dbProvider.database;
    final existing = await getTotalBudget(ledgerId, month);
    if (existing == null) {
      await db.insert('budgets', {
        'ledger_id': ledgerId,
        'month': month,
        'scope': BudgetScope.total.name,
        'category_id': null,
        'amount': amount,
      });
    } else {
      await db.update(
        'budgets',
        {'amount': amount},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
  }

  Future<List<Budget>> getCategoryBudgets(int ledgerId, String month) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'budgets',
      where: "ledger_id = ? AND month = ? AND scope = 'category'",
      whereArgs: [ledgerId, month],
      orderBy: 'id ASC',
    );
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> setCategoryBudget({
    required int ledgerId,
    required String month,
    required int categoryId,
    required double amount,
  }) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'budgets',
      where: "ledger_id = ? AND month = ? AND scope = 'category' AND category_id = ?",
      whereArgs: [ledgerId, month, categoryId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert('budgets', {
        'ledger_id': ledgerId,
        'month': month,
        'scope': BudgetScope.category.name,
        'category_id': categoryId,
        'amount': amount,
      });
    } else {
      await db.update(
        'budgets',
        {'amount': amount},
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
  }

  Future<void> deleteBudget(int id) async {
    final db = await _dbProvider.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Budget>> getBudgets(int ledgerId) async {
    final db = await _dbProvider.database;
    final rows = await db.query('budgets', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> clearLedgerData(int ledgerId) async {
    final db = await _dbProvider.database;
    final piggies = await db.query('piggy_banks', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    for (final p in piggies) {
      await db.delete('piggy_transfers', where: 'piggy_id = ?', whereArgs: [p['id']]);
    }
    await db.delete('piggy_banks', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    await db.delete('transactions', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    await db.delete('budgets', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    await db.delete('quick_templates', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    await db.delete('recurring_bills', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    await db.update(
      'ledgers',
      {'initial_balance': 0},
      where: 'id = ?',
      whereArgs: [ledgerId],
    );
    await db.update(
      'fund_accounts',
      {'balance': 0},
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
    );
  }

  Future<List<RecurringBill>> getRecurringBills(int ledgerId) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'recurring_bills',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: 'enabled DESC, next_due_at ASC, id ASC',
    );
    return rows.map(RecurringBill.fromMap).toList();
  }

  Future<int> upsertRecurringBill(RecurringBill b) async {
    final db = await _dbProvider.database;
    if (b.id == null) {
      return db.insert('recurring_bills', b.toMap()..remove('id'));
    }
    await db.update(
      'recurring_bills',
      b.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [b.id],
    );
    return b.id!;
  }

  Future<void> deleteRecurringBill(int id) async {
    final db = await _dbProvider.database;
    await db.delete('recurring_bills', where: 'id = ?', whereArgs: [id]);
  }

  /// 将到期的自动续费写入支出流水，并推进下次扣款日（可补记多期）
  Future<int> processDueRecurring(int ledgerId) async {
    final bills = await getRecurringBills(ledgerId);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    var posted = 0;
    for (var bill in bills) {
      if (!bill.enabled) continue;
      var due = DateTime(bill.nextDueAt.year, bill.nextDueAt.month, bill.nextDueAt.day);
      // 防止异常死循环
      var guard = 0;
      while (!due.isAfter(todayDate) && guard < 36) {
        guard++;
        final occurred = DateTime(due.year, due.month, due.day, 12);
        await upsertTransaction(
          Transaction(
            ledgerId: ledgerId,
            type: TxType.expense,
            amount: bill.amount,
            categoryId: bill.categoryId,
            fundAccountId: bill.fundAccountId,
            note: bill.note.isEmpty ? '自动续费·${bill.title}' : bill.note,
            occurredAt: occurred,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        due = RecurringBill.advance(due, bill.period);
        bill = bill.copyWith(
          nextDueAt: due,
          lastPostedAt: occurred,
        );
        await upsertRecurringBill(bill);
        posted++;
      }
    }
    return posted;
  }

  Future<List<QuickTemplate>> getTemplates(int ledgerId) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'quick_templates',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: 'sort ASC, id ASC',
    );
    return rows.map(QuickTemplate.fromMap).toList();
  }

  Future<int> upsertTemplate(QuickTemplate t) async {
    final db = await _dbProvider.database;
    if (t.id == null) {
      return db.insert('quick_templates', t.toMap()..remove('id'));
    }
    await db.update(
      'quick_templates',
      t.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [t.id],
    );
    return t.id!;
  }

  Future<void> deleteTemplate(int id) async {
    final db = await _dbProvider.database;
    await db.delete('quick_templates', where: 'id = ?', whereArgs: [id]);
  }

  /// 近若干月平均每月转入（用于速度估算）
  Future<double> avgMonthlyDepositIn(int piggyId, {int months = 3}) async {
    final now = DateTime.now();
    var total = 0.0;
    var used = 0;
    for (var i = 0; i < months; i++) {
      final m = DateTime(now.year, now.month - i);
      final v = await monthDepositIn(piggyId, m);
      if (v > 0 || i == 0) {
        total += v;
        used++;
      }
    }
    if (used == 0) return 0;
    return total / used;
  }

  Future<Map<String, dynamic>> exportJsonMap(int ledgerId) async {
    final settings = await getSettings();
    final ledger = await getLedger(ledgerId);
    final categories = await getCategories(ledgerId);
    final txs = await getTransactions(ledgerId);
    final piggies = await getPiggies(ledgerId);
    final piggyIds = piggies.map((p) => p.id).whereType<int>().toSet();
    final allTransfers = await getAllTransfers();
    final transfers = allTransfers.where((t) => piggyIds.contains(t.piggyId)).toList();
    final budgets = await getBudgets(ledgerId);
    final templates = await getTemplates(ledgerId);
    final funds = await getFundAccounts(ledgerId);
    final recurrings = await getRecurringBills(ledgerId);
    return {
      'app': 'linyue_ledger',
      'version': 7,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': {
        'budget_enabled': settings.budgetEnabled,
      },
      'ledger': ledger?.toMap(),
      'categories': categories.map((e) => e.toMap()).toList(),
      'transactions': txs.map((e) => e.toMap()).toList(),
      'piggy_banks': piggies.map((e) => e.toMap()).toList(),
      'piggy_transfers': transfers.map((e) => e.toMap()).toList(),
      'budgets': budgets.map((e) => e.toMap()).toList(),
      'quick_templates': templates.map((e) => e.toMap()).toList(),
      'fund_accounts': funds.map((e) => e.toMap()).toList(),
      'recurring_bills': recurrings.map((e) => e.toMap()).toList(),
    };
  }

  /// 导入备份到指定账本（覆盖流水/霜匣/预算/模板；分类按名称合并）
  Future<void> importJsonToLedger(int ledgerId, Map<String, dynamic> data) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      final piggies = await txn.query('piggy_banks', where: 'ledger_id = ?', whereArgs: [ledgerId]);
      for (final p in piggies) {
        await txn.delete('piggy_transfers', where: 'piggy_id = ?', whereArgs: [p['id']]);
      }
      await txn.delete('piggy_banks', where: 'ledger_id = ?', whereArgs: [ledgerId]);
      await txn.delete('transactions', where: 'ledger_id = ?', whereArgs: [ledgerId]);
      await txn.delete('budgets', where: 'ledger_id = ?', whereArgs: [ledgerId]);
      await txn.delete('quick_templates', where: 'ledger_id = ?', whereArgs: [ledgerId]);
      await txn.delete('fund_accounts', where: 'ledger_id = ?', whereArgs: [ledgerId]);
      await txn.delete('recurring_bills', where: 'ledger_id = ?', whereArgs: [ledgerId]);

      await txn.update(
        'ledgers',
        {'initial_balance': 0},
        where: 'id = ?',
        whereArgs: [ledgerId],
      );

      final existingCats = await txn.query('categories', where: 'ledger_id = ?', whereArgs: [ledgerId]);
      final nameToId = <String, int>{};
      for (final c in existingCats) {
        nameToId['${c['type']}|${c['name']}'] = c['id'] as int;
      }

      final oldCatToNew = <int, int>{};
      final catList = (data['categories'] as List?) ?? [];
      for (final raw in catList) {
        final m = Map<String, Object?>.from(raw as Map);
        final oldId = m['id'] as int?;
        final key = '${m['type']}|${m['name']}';
        if (nameToId.containsKey(key)) {
          if (oldId != null) oldCatToNew[oldId] = nameToId[key]!;
          continue;
        }
        final newId = await txn.insert('categories', {
          'ledger_id': ledgerId,
          'name': m['name'],
          'type': m['type'],
          'icon_key': m['icon_key'] ?? 'other',
          'sort': m['sort'] ?? 0,
          'is_system': m['is_system'] ?? 0,
        });
        nameToId[key] = newId;
        if (oldId != null) oldCatToNew[oldId] = newId;
      }

      final fallbackCat = nameToId.values.isEmpty
          ? null
          : nameToId.values.first;

      final oldFundToNew = <int, int>{};
      final fundList = (data['fund_accounts'] as List?) ?? [];
      if (fundList.isNotEmpty) {
        for (final raw in fundList) {
          final m = Map<String, Object?>.from(raw as Map);
          final oldId = m['id'] as int?;
          final newId = await txn.insert('fund_accounts', {
            'ledger_id': ledgerId,
            'name': m['name'],
            'kind': m['kind'] ?? FundKind.custom.name,
            'balance': m['balance'] ?? 0,
            'icon_key': m['icon_key'] ?? 'wallet',
            'sort': m['sort'] ?? 0,
            'is_preset': m['is_preset'] ?? 0,
          });
          if (oldId != null) oldFundToNew[oldId] = newId;
        }
      } else {
        final legacyBal = data['ledger'] is Map
            ? ((data['ledger'] as Map)['initial_balance'] as num?)?.toDouble() ?? 0
            : 0.0;
        for (final a in FundAccount.presetSeeds(ledgerId, cashBalance: legacyBal)) {
          await txn.insert('fund_accounts', a.toMap()..remove('id'));
        }
      }

      int? fallbackFundId;
      final fundRows = await txn.query(
        'fund_accounts',
        where: 'ledger_id = ?',
        whereArgs: [ledgerId],
        orderBy: 'sort ASC, id ASC',
      );
      for (final f in fundRows) {
        if (f['kind'] == 'cash') {
          fallbackFundId = f['id'] as int;
          break;
        }
      }
      fallbackFundId ??= fundRows.isEmpty ? null : fundRows.first['id'] as int;

      final txList = (data['transactions'] as List?) ?? [];
      for (final raw in txList) {
        final m = Map<String, Object?>.from(raw as Map);
        final oldCat = m['category_id'] as int?;
        final catId = (oldCat != null ? oldCatToNew[oldCat] : null) ?? fallbackCat;
        if (catId == null) continue;
        final oldFund = m['fund_account_id'] as int?;
        final fundId = (oldFund != null ? oldFundToNew[oldFund] : null) ?? fallbackFundId;
        await txn.insert('transactions', {
          'ledger_id': ledgerId,
          'type': m['type'],
          'amount': m['amount'],
          'category_id': catId,
          'fund_account_id': fundId,
          'note': m['note'] ?? '',
          'occurred_at': m['occurred_at'],
          'created_at': m['created_at'] ?? m['occurred_at'],
          'updated_at': m['updated_at'] ?? m['occurred_at'],
        });
      }

      final oldPiggyToNew = <int, int>{};
      final piggyList = (data['piggy_banks'] as List?) ?? [];
      for (final raw in piggyList) {
        final m = Map<String, Object?>.from(raw as Map);
        final oldId = m['id'] as int?;
        final newId = await txn.insert('piggy_banks', {
          'ledger_id': ledgerId,
          'name': m['name'],
          'target_amount': m['target_amount'],
          'current_amount': m['current_amount'] ?? 0,
          'monthly_target': m['monthly_target'] ?? 0,
          'task_scale': m['task_scale'] ?? 'small',
          'note': m['note'] ?? '',
          'cover_color': m['cover_color'] ?? '#7EB6D4',
          'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
          'achieved_at': m['achieved_at'],
          'target_date': m['target_date'],
        });
        if (oldId != null) oldPiggyToNew[oldId] = newId;
      }

      final transferList = (data['piggy_transfers'] as List?) ?? [];
      for (final raw in transferList) {
        final m = Map<String, Object?>.from(raw as Map);
        final oldPid = m['piggy_id'] as int?;
        final newPid = oldPid == null ? null : oldPiggyToNew[oldPid];
        if (newPid == null) continue;
        await txn.insert('piggy_transfers', {
          'piggy_id': newPid,
          'direction': m['direction'],
          'amount': m['amount'],
          'occurred_at': m['occurred_at'],
          'note': m['note'],
        });
      }

      final budgetList = (data['budgets'] as List?) ?? [];
      for (final raw in budgetList) {
        final m = Map<String, Object?>.from(raw as Map);
        int? catId;
        final oldCat = m['category_id'] as int?;
        if (oldCat != null) catId = oldCatToNew[oldCat];
        await txn.insert('budgets', {
          'ledger_id': ledgerId,
          'month': m['month'],
          'scope': m['scope'] ?? 'total',
          'category_id': catId,
          'amount': m['amount'],
        });
      }

      final tplList = (data['quick_templates'] as List?) ?? [];
      for (final raw in tplList) {
        final m = Map<String, Object?>.from(raw as Map);
        final oldCat = m['category_id'] as int?;
        final catId = (oldCat != null ? oldCatToNew[oldCat] : null) ?? fallbackCat;
        if (catId == null) continue;
        await txn.insert('quick_templates', {
          'ledger_id': ledgerId,
          'title': m['title'],
          'type': m['type'],
          'amount': m['amount'],
          'category_id': catId,
          'note': m['note'] ?? '',
          'sort': m['sort'] ?? 0,
        });
      }

      final recurList = (data['recurring_bills'] as List?) ?? [];
      for (final raw in recurList) {
        final m = Map<String, Object?>.from(raw as Map);
        final oldCat = m['category_id'] as int?;
        final catId = (oldCat != null ? oldCatToNew[oldCat] : null) ?? fallbackCat;
        if (catId == null) continue;
        final oldFund = m['fund_account_id'] as int?;
        final fundId = (oldFund != null ? oldFundToNew[oldFund] : null) ?? fallbackFundId;
        await txn.insert('recurring_bills', {
          'ledger_id': ledgerId,
          'title': m['title'],
          'amount': m['amount'],
          'category_id': catId,
          'fund_account_id': fundId,
          'period': m['period'] ?? 'monthly',
          'next_due_at': m['next_due_at'],
          'note': m['note'] ?? '',
          'enabled': m['enabled'] ?? 1,
          'template_key': m['template_key'],
          'last_posted_at': m['last_posted_at'],
          'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<String> exportCsv(int ledgerId) async {
    final cats = {for (final c in await getCategories(ledgerId)) c.id!: c};
    final txs = await getTransactions(ledgerId);
    final buf = StringBuffer('id,type,amount,category,note,occurred_at\n');
    for (final t in txs) {
      final cat = cats[t.categoryId]?.name ?? '';
      final note = t.note.replaceAll('"', '""');
      buf.writeln(
        '${t.id},${t.type.name},${t.amount},"$cat","$note",${t.occurredAt.toIso8601String()}',
      );
    }
    return buf.toString();
  }

  Future<int> onboard({
    required LedgerPersona persona,
    required double initialBalance,
    String? name,
  }) async {
    final id = await createLedger(
      name: name ?? PersonaPresets.defaultLedgerName(persona),
      persona: persona,
      initialBalance: initialBalance,
    );
    await saveSettings(AppSettings(
      onboarded: true,
      budgetEnabled: false,
      activeLedgerId: id,
    ));
    return id;
  }

  static String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
}
