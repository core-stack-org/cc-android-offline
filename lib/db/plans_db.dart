import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:nrmflutter/config/api_config.dart';

class PlansDatabase {
  static final PlansDatabase instance = PlansDatabase._init();
  static Database? _database;

  PlansDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('plans.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE plans(
      id INTEGER PRIMARY KEY,
      plan TEXT,
      state TEXT,
      district INTEGER,
      block INTEGER,
      tehsil INTEGER,
      village_name TEXT,
      gram_panchayat TEXT,
      facilitator_name TEXT,
      organization TEXT,
      organization_name TEXT,
      project INTEGER,
      project_name TEXT,
      created_by INTEGER,
      created_by_name TEXT,
      created_at TEXT,
      updated_at TEXT,
      enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
      is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0,1)),
      is_dpr_generated INTEGER NOT NULL DEFAULT 0 CHECK (is_dpr_generated IN (0,1)),
      is_dpr_reviewed INTEGER NOT NULL DEFAULT 0 CHECK (is_dpr_reviewed IN (0,1)),
      is_dpr_approved INTEGER NOT NULL DEFAULT 0 CHECK (is_dpr_approved IN (0,1))
    )
  ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE plans ADD COLUMN tehsil INTEGER');
      await db.execute(
          'UPDATE plans SET tehsil = block WHERE tehsil IS NULL AND block IS NOT NULL');
    }
  }

  Future<void> insertPlansData(List<Map<String, dynamic>> plans) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('plans');

      // Insert new data
      for (var plan in plans) {
        final tehsilValue = plan['tehsil_soi'];

        await txn.insert(
          'plans',
          {
            'id': plan['id'],
            'plan': plan['plan'],
            'state': plan['state_soi']?.toString(),
            'district': plan['district_soi'],
            'block': plan['tehsil_soi'],
            'tehsil': tehsilValue,
            'village_name': plan['village_name'],
            'gram_panchayat': plan['gram_panchayat'],
            'facilitator_name': plan['facilitator_name'],
            'organization': plan['organization'],
            'organization_name': plan['organization_name'],
            'project': plan['project'],
            'project_name': plan['project_name'],
            'created_by': plan['created_by'],
            'created_by_name': plan['created_by_name'],
            'created_at': plan['created_at'],
            'updated_at': plan['updated_at'],
            'enabled': (plan['enabled'] == true) ? 1 : 0,
            'is_completed': (plan['is_completed'] == true) ? 1 : 0,
            'is_dpr_generated': (plan['is_dpr_generated'] == true) ? 1 : 0,
            'is_dpr_reviewed': (plan['is_dpr_reviewed'] == true) ? 1 : 0,
            'is_dpr_approved': (plan['is_dpr_approved'] == true) ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPlansForTehsil(int tehsilId) async {
    final db = await database;
    return await db.query(
      'plans',
      where: 'tehsil = ?',
      whereArgs: [tehsilId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllPlans() async {
    final db = await database;
    return await db.query('plans');
  }

  // Method to sync plans with the server
  Future<void> syncPlans() async {
    try {
      print('DEBUG: Syncing plans from API...');
      final response = await http.get(
        Uri.parse('https://geoserver.core-stack.org/api/v1/watershed/plans'),
        headers: {
          "Content-Type": "application/json",
          'X-API-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final plansList = List<Map<String, dynamic>>.from(data);
        await insertPlansData(plansList);
      } else {
        throw Exception('Failed to fetch plans');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
