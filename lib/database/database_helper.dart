import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {

  static final DatabaseHelper instance =
      DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {

    if (_database != null) {
      return _database!;
    }

    _database =
        await _initDB(
      'studyflow.db',
    );

    return _database!;
  }

  Future<Database> _initDB(
      String filePath) async {

    final dbPath =
        await getDatabasesPath();

    final path =
        join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(
    Database db,
    int version,
  ) async {

    await db.execute('''
      CREATE TABLE materia(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        professor TEXT,
        cor INTEGER,
        horario TEXT,
        meta_horas REAL,
        status TEXT
      )
    ''');
  }
}