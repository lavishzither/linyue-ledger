import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models.dart';
import 'presets/persona_presets.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<void> initPlatform() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'qingshuang_ledger.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await _createV2(db);
        await _ensureV4(db);
        await _ensureV5(db);
        await _ensureV6(db);
        await _ensureV7(db);
        await db.insert('settings', {
          'id': 1,
          'onboarded': 0,
          'budget_enabled': 0,
          'active_ledger_id': null,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeV1toV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeV2toV3(db);
        }
        if (oldVersion < 4) {
          await _ensureV4(db);
        }
        if (oldVersion < 5) {
          await _ensureV5(db);
        }
        if (oldVersion < 6) {
          await _ensureV6(db);
        }
        if (oldVersion < 7) {
          await _ensureV7(db);
        }
      },
    );
  }

  Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY NOT NULL,
        onboarded INTEGER NOT NULL DEFAULT 0,
        budget_enabled INTEGER NOT NULL DEFAULT 0,
        active_ledger_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        persona TEXT NOT NULL,
        initial_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        is_system INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        occurred_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE piggy_banks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        monthly_target REAL NOT NULL DEFAULT 0,
        task_scale TEXT NOT NULL DEFAULT 'small',
        note TEXT NOT NULL DEFAULT '',
        cover_color TEXT NOT NULL,
        created_at TEXT NOT NULL,
        achieved_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE piggy_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        piggy_id INTEGER NOT NULL,
        direction TEXT NOT NULL,
        amount REAL NOT NULL,
        occurred_at TEXT NOT NULL,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        scope TEXT NOT NULL,
        category_id INTEGER,
        amount REAL NOT NULL
      )
    ''');
  }

  Future<void> _upgradeV1toV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        persona TEXT NOT NULL,
        initial_balance REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    final settings = await db.query('settings', where: 'id = 1');
    final oldBalance = settings.isEmpty
        ? 0.0
        : (settings.first['initial_balance'] as num?)?.toDouble() ?? 0.0;

    final ledgerId = await db.insert('ledgers', {
      'name': '通用账本',
      'persona': LedgerPersona.general.name,
      'initial_balance': oldBalance,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _safeAddColumn(db, 'categories', 'ledger_id', 'INTEGER NOT NULL DEFAULT $ledgerId');
    await _safeAddColumn(db, 'transactions', 'ledger_id', 'INTEGER NOT NULL DEFAULT $ledgerId');
    await _safeAddColumn(db, 'piggy_banks', 'ledger_id', 'INTEGER NOT NULL DEFAULT $ledgerId');
    await _safeAddColumn(db, 'piggy_banks', 'task_scale', "TEXT NOT NULL DEFAULT 'small'");
    await _safeAddColumn(db, 'piggy_banks', 'note', "TEXT NOT NULL DEFAULT ''");
    await _safeAddColumn(db, 'budgets', 'ledger_id', 'INTEGER NOT NULL DEFAULT $ledgerId');
    await _safeAddColumn(db, 'settings', 'active_ledger_id', 'INTEGER');

    await db.update('settings', {'active_ledger_id': ledgerId}, where: 'id = 1');
  }

  Future<void> _upgradeV2toV3(Database db) async {
    await _safeAddColumn(
      db,
      'piggy_banks',
      'monthly_target',
      'REAL NOT NULL DEFAULT 0',
    );
  }

  Future<void> _ensureV4(Database db) async {
    await _safeAddColumn(db, 'piggy_banks', 'target_date', 'TEXT');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quick_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _ensureV7(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        fund_account_id INTEGER,
        period TEXT NOT NULL,
        next_due_at TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1,
        template_key TEXT,
        last_posted_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureV6(Database db) async {
    await _safeAddColumn(db, 'transactions', 'fund_account_id', 'INTEGER');
    final ledgers = await db.query('ledgers');
    for (final row in ledgers) {
      final lid = row['id'] as int;
      final funds = await db.query(
        'fund_accounts',
        where: 'ledger_id = ?',
        whereArgs: [lid],
        orderBy: 'sort ASC, id ASC',
      );
      if (funds.isEmpty) continue;
      int? cashId;
      for (final f in funds) {
        if (f['kind'] == 'cash') {
          cashId = f['id'] as int;
          break;
        }
      }
      cashId ??= funds.first['id'] as int;
      await db.update(
        'transactions',
        {'fund_account_id': cashId},
        where: 'ledger_id = ? AND fund_account_id IS NULL',
        whereArgs: [lid],
      );
    }
  }

  Future<void> _ensureV5(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fund_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        icon_key TEXT NOT NULL,
        sort INTEGER NOT NULL DEFAULT 0,
        is_preset INTEGER NOT NULL DEFAULT 0
      )
    ''');
    final ledgers = await db.query('ledgers');
    for (final row in ledgers) {
      final lid = row['id'] as int;
      final existing = await db.query(
        'fund_accounts',
        where: 'ledger_id = ?',
        whereArgs: [lid],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      final oldBal = (row['initial_balance'] as num?)?.toDouble() ?? 0;
      for (final a in FundAccount.presetSeeds(lid, cashBalance: oldBal)) {
        await db.insert('fund_accounts', a.toMap()..remove('id'));
      }
      if (oldBal != 0) {
        await db.update(
          'ledgers',
          {'initial_balance': 0},
          where: 'id = ?',
          whereArgs: [lid],
        );
      }
    }
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String typeDecl,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $typeDecl');
    } catch (_) {
      // column may already exist
    }
  }

  static Future<void> seedCategoriesForLedger(
    Database db,
    int ledgerId,
    LedgerPersona persona,
  ) async {
    final list = PersonaPresets.categories(persona);
    var sort = 0;
    for (final item in list) {
      await db.insert('categories', {
        'ledger_id': ledgerId,
        'name': item.$1,
        'type': item.$3.name,
        'icon_key': item.$2,
        'sort': sort++,
        'is_system': 1,
      });
    }
  }
}
