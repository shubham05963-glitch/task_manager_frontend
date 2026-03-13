import 'package:frontend/models/task_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TaskLocalRepository {
  final String tableName = "tasks";

  Database? _database;

  /// GET DATABASE
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDb();
    return _database!;
  }

  /// INIT DATABASE
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "tasks.db");

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE $tableName(
          id TEXT PRIMARY KEY,
          uid TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          due_at TEXT NOT NULL,
          hex_color TEXT NOT NULL,
          is_synced INTEGER NOT NULL,
          is_completed INTEGER DEFAULT 0,
          completed_at TEXT
        )
        ''');
      },
    );
  }

  /// INSERT SINGLE TASK
  Future<void> insertTask(TaskModel task) async {
    final db = await database;

    await db.insert(
      tableName,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// INSERT MULTIPLE TASKS (SAFE FOR SYNC)
  Future<void> insertTasks(List<TaskModel> tasks) async {
    final db = await database;

    final batch = db.batch();

    for (final task in tasks) {
      batch.insert(
        tableName,
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace, // Changed to replace to update existing records
      );
    }

    await batch.commit(noResult: true);
  }

  /// GET ALL TASKS FOR USER
  Future<List<TaskModel>> getTasks(String uid) async {
    final db = await database;

    final result = await db.query(
      tableName,
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'due_at ASC',
    );

    return result.map((e) => TaskModel.fromMap(e)).toList();
  }

  /// GET COMPLETED TASKS
  Future<List<TaskModel>> getCompletedTasks(String uid) async {
    final db = await database;

    final result = await db.query(
      tableName,
      where: 'uid = ? AND is_completed = ?',
      whereArgs: [uid, 1],
      orderBy: 'due_at ASC',
    );

    return result.map((e) => TaskModel.fromMap(e)).toList();
  }

  /// GET INCOMPLETE TASKS
  Future<List<TaskModel>> getIncompleteTasks(String uid) async {
    final db = await database;

    final result = await db.query(
      tableName,
      where: 'uid = ? AND is_completed = ?',
      whereArgs: [uid, 0],
      orderBy: 'due_at ASC',
    );

    return result.map((e) => TaskModel.fromMap(e)).toList();
  }

  /// GET UNSYNCED TASKS
  Future<List<TaskModel>> getUnsyncedTasks(String uid) async {
    final db = await database;

    final result = await db.query(
      tableName,
      where: 'uid = ? AND is_synced = ?',
      whereArgs: [uid, 0],
    );

    return result.map((e) => TaskModel.fromMap(e)).toList();
  }

  /// UPDATE TASK
  Future<void> updateTask(TaskModel task) async {
    final db = await database;

    await db.update(
      tableName,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// DELETE TASK
  Future<void> deleteTask(String id) async {
    final db = await database;

    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// UPDATE SYNC VALUE
  Future<void> updateRowValue(String id, int newValue) async {
    final db = await database;

    await db.update(
      tableName,
      {'is_synced': newValue},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
