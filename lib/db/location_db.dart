import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocationDatabase {
  static final LocationDatabase instance = LocationDatabase._init();
  static Database? _database;

  LocationDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('locations.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE states(
        state_id TEXT PRIMARY KEY,
        label TEXT,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE districts(
        district_id TEXT PRIMARY KEY,
        state_id TEXT,
        label TEXT,
        value TEXT,
        FOREIGN KEY (state_id) REFERENCES states (state_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE blocks(
        block_id TEXT PRIMARY KEY,
        district_id TEXT,
        label TEXT,
        value TEXT,
        FOREIGN KEY (district_id) REFERENCES districts (district_id)
      )
    ''');
  }

  Future<void> insertLocationData(List<Map<String, dynamic>> data) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('blocks');
      await txn.delete('districts');
      await txn.delete('states');

      // Insert new data
      for (var state in data) {
        await txn.insert('states', {
          'state_id': state['state_id'],
          'label': state['label'],
          'value': state['value'],
        });

        for (var district in state['district']) {
          await txn.insert('districts', {
            'district_id': district['district_id'],
            'state_id': state['state_id'],
            'label': district['label'],
            'value': district['value'],
          });

          for (var block in district['blocks']) {
            await txn.insert('blocks', {
              'block_id': block['block_id'],
              'district_id': district['district_id'],
              'label': block['label'],
              'value': block['value'],
            });
          }
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getLocationData() async {
    final db = await database;

    final states = await db.query('states');
    final districts = await db.query('districts');
    final blocks = await db.query('blocks');

    final blocksByDistrict = <String, List<Map<String, dynamic>>>{};
    for (var block in blocks) {
      final districtId = block['district_id'] as String;
      blocksByDistrict.putIfAbsent(districtId, () => []).add(block);
    }

    final districtsByState = <String, List<Map<String, dynamic>>>{};
    for (var district in districts) {
      final stateId = district['state_id'] as String;
      final districtId = district['district_id'] as String;
      final districtWithBlocks = {
        ...district,
        'blocks': blocksByDistrict[districtId] ?? [],
      };
      districtsByState.putIfAbsent(stateId, () => []).add(districtWithBlocks);
    }

    final result = states.map((state) {
      final stateId = state['state_id'] as String;
      return {
        ...state,
        'district': districtsByState[stateId] ?? [],
      };
    }).toList();

    return result;
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
