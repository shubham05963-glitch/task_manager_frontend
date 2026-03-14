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
      // Logic to prevent "Completed" tasks from ever being reverted to "Incomplete" by the server
      // 1. Only update if the local task is already synced (meaning no pending local changes)
      // 2. OR if the incoming data is strictly newer (timestamp check)
      // 3. AND NEVER let a completed local task (is_completed = 1) be overwritten by an incomplete remote task (excluded.is_completed = 0)
      batch.execute('''
        INSERT INTO $tableName (id, uid, title, description, created_at, updated_at, due_at, hex_color, is_synced, is_completed, completed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          description = excluded.description,
          updated_at = excluded.updated_at,
          due_at = excluded.due_at,
          hex_color = excluded.hex_color,
          is_synced = excluded.is_synced,
          is_completed = CASE 
            WHEN is_completed = 1 THEN 1 
            ELSE excluded.is_completed 
          END,
          completed_at = CASE 
            WHEN is_completed = 1 THEN completed_at 
            ELSE excluded.completed_at 
          END
        WHERE is_synced = 1 OR updated_at < excluded.updated_at
      ''', [
        task.id,
        task.uid,
        task.title,
        task.description,
        task.createdAt.toIso8601String(),
        task.updatedAt.toIso8601String(),
        task.dueAt.toIso8601String(),
        task.toMap()['hex_color'],
        1, 
        task.isCompleted,
        task.completedAt?.toIso8601String(),
      ]);
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
