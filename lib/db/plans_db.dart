import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

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
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE plans(
        plan_id INTEGER PRIMARY KEY,
        facilitator_name TEXT,
        plan TEXT,
        village_name TEXT,
        gram_panchayat TEXT,
        state TEXT,
        district INTEGER,
        block INTEGER
      )
    ''');
  }

  Future<void> insertPlansData(List<Map<String, dynamic>> plans) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('plans');

      // Insert new data
      for (var plan in plans) {
        await txn.insert('plans', {
          'plan_id': plan['plan_id'],
          'facilitator_name': plan['facilitator_name'],
          'plan': plan['plan'],
          'village_name': plan['village_name'],
          'gram_panchayat': plan['gram_panchayat'],
          'state': plan['state'],
          'district': plan['district'],
          'block': plan['block'],
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPlansForBlock(int blockId) async {
    final db = await database;
    return await db.query(
      'plans',
      where: 'block = ?',
      whereArgs: [blockId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllPlans() async {
    final db = await database;
    return await db.query('plans');
  }

  // Method to sync plans with the server
  Future<void> syncPlans() async {
    try {
      final response = await http.get(
        Uri.parse('https://geoserver.core-stack.org/api/v1/get_plans/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await insertPlansData(List<Map<String, dynamic>>.from(data['plans']));
      } else {
        throw Exception('Failed to fetch plans');
      }
    } catch (e) {
      print('Error syncing plans: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
