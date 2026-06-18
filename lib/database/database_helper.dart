import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'db_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const String _dbName = 'studyflow.db';
  static const int _dbVersion = 13; // v11: vincula notas geradas por provas

  // Tabelas
  static const String tableMateria = 'materia';
  static const String tableTarefa = 'tarefa';
  static const String tableProva = 'prova';
  static const String tableDocumento = 'documento';
  static const String tableNota = 'nota'; // NOVA

  // Coluna comum
  static const String colIdUsuario = 'id_usuario';

  // Materia
  static const String colMateriaId = 'id';
  static const String colMateriaNome = 'nome';
  static const String colMateriaProfessor = 'professor';
  static const String colMateriaCor = 'cor';
  static const String colMateriaIcone = 'icone';
  static const String colMateriaHorario = 'horario';
  static const String colMateriaMetaHoras = 'meta_horas';
  static const String colMateriaStatus = 'status';

  // Tarefa
  static const String colTarefaId = 'id';
  static const String colTarefaTitulo = 'titulo';
  static const String colTarefaDescricao = 'descricao';
  static const String colTarefaConcluida = 'concluida';
  static const String colTarefaIdMateria = 'id_materia';
  static const String colTarefaDataCriacao = 'data_criacao';
  static const String colTarefaDataEntrega = 'data_entrega';
  static const String colTarefaDataConclusao = 'data_conclusao';
  static const String colTarefaIdDocumento = 'id_documento';
  static const String colTarefaIdProva = 'id_prova';
  static const String colTarefaPrioridade = 'prioridade';
  static const String colDocumentoIdTarefa = 'id_tarefa';

  // Prova
  static const String colProvaId = 'id';
  static const String colProvaTitulo = 'titulo';
  static const String colProvaDescricao = 'descricao';
  static const String colProvaDataCriacao = 'data_criacao';
  static const String colProvaDataProva = 'data_prova';
  static const String colProvaNota = 'nota';
  static const String colProvaPeso = 'peso';
  static const String colProvaRealizada = 'realizada';
  static const String colProvaIdMateria = 'id_materia';
  static const String colProvaIdDocumento = 'id_documento';

  // Documento
  static const String colDocumentoId = 'id';
  static const String colDocumentoTitulo = 'titulo';
  static const String colDocumentoTipo = 'tipo';
  static const String colDocumentoCaminho = 'caminho';
  static const String colDocumentoNomeArquivo = 'nome_arquivo';
  static const String colDocumentoDescricao = 'descricao';
  static const String colDocumentoResumo = 'resumo';
  static const String colDocumentoTopicos = 'topicos';
  static const String colDocumentoSugeridos = 'sugeridos';
  static const String colDocumentoQuestoes = 'questoes';
  static const String colDocumentoRespostas = 'respostas';
  static const String colDocumentoStatus = 'status';
  static const String colDocumentoErro = 'erro';
  static const String colDocumentoDataCriacao = 'data_criacao';
  static const String colDocumentoIdProva = 'id_prova';

  // Nota (NOVA)
  static const String colNotaId = 'id';
  static const String colNotaIdMateria = 'id_materia';
  static const String colNotaDescricao = 'descricao';
  static const String colNotaValor = 'valor';
  static const String colNotaPeso = 'peso';
  static const String colNotaTipo = 'tipo';
  static const String colNotaData = 'data';
  static const String colNotaIdProva = 'id_prova';
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      final db = await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );

      // Garante schema completo em bancos antigos
      await _ensureAllColumnsExist(db);

      return db;
    } catch (e) {
      throw Exception('Erro ao inicializar banco de dados: $e');
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE $tableMateria(
          $colMateriaId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colMateriaNome TEXT NOT NULL UNIQUE,
          $colMateriaProfessor TEXT,
          $colMateriaCor INTEGER,
          $colMateriaIcone INTEGER,
          $colMateriaHorario TEXT,
          $colMateriaMetaHoras REAL DEFAULT 0,
          $colMateriaStatus TEXT DEFAULT 'ativa',
          $colIdUsuario TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableTarefa(
          $colTarefaId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colTarefaTitulo TEXT NOT NULL,
          $colTarefaDescricao TEXT,
          $colTarefaConcluida INTEGER DEFAULT 0,
          $colTarefaIdMateria INTEGER NOT NULL,
          $colTarefaIdDocumento INTEGER,
          $colTarefaIdProva INTEGER,
          $colTarefaDataCriacao TEXT,
          $colTarefaDataEntrega TEXT,
          $colTarefaDataConclusao TEXT,
          $colTarefaPrioridade TEXT DEFAULT 'media',
          $colIdUsuario TEXT,
          FOREIGN KEY($colTarefaIdMateria) REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableDocumento(
          $colDocumentoId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colDocumentoTitulo TEXT NOT NULL,
          $colDocumentoTipo TEXT,
          $colDocumentoCaminho TEXT NOT NULL,
          $colDocumentoNomeArquivo TEXT NOT NULL,
          $colDocumentoDescricao TEXT,
          $colDocumentoResumo TEXT,
          $colDocumentoTopicos TEXT,
          $colDocumentoSugeridos TEXT,
          $colDocumentoQuestoes TEXT,
          $colDocumentoRespostas TEXT,
          $colDocumentoStatus TEXT DEFAULT 'pendente',
          $colDocumentoErro TEXT,
          $colDocumentoDataCriacao TEXT NOT NULL,
          $colDocumentoIdProva INTEGER,
          $colIdUsuario TEXT,
          $colDocumentoIdTarefa INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableProva(
          $colProvaId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colProvaTitulo TEXT NOT NULL,
          $colProvaDescricao TEXT,
          $colProvaDataCriacao TEXT,
          $colProvaDataProva TEXT,
          $colProvaNota REAL,
          $colProvaPeso REAL DEFAULT 1.0,
          $colProvaRealizada INTEGER DEFAULT 0,
          $colProvaIdMateria INTEGER NOT NULL,
          $colProvaIdDocumento INTEGER,
          $colIdUsuario TEXT,
          FOREIGN KEY($colProvaIdMateria) REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE $tableNota(
          $colNotaId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colNotaIdMateria INTEGER NOT NULL,
          $colNotaDescricao TEXT NOT NULL,
          $colNotaValor REAL NOT NULL,
          $colNotaPeso REAL DEFAULT 1.0,
          $colNotaTipo TEXT DEFAULT 'prova',
          $colNotaData TEXT,
          $colNotaIdProva INTEGER,
          $colIdUsuario TEXT,
          FOREIGN KEY($colNotaIdMateria) REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
        )
      ''');

      await _createAllIndexes(db);
    } catch (e) {
      throw Exception('Erro ao criar tabelas: $e');
    }
  }

  Future<void> _createAllIndexes(Database db) async {
    final indexes = {
      'idx_materia_usuario': '$tableMateria($colIdUsuario)',
      'idx_tarefa_usuario': '$tableTarefa($colIdUsuario)',
      'idx_tarefa_materia': '$tableTarefa($colTarefaIdMateria)',
      'idx_tarefa_prova': '$tableTarefa($colTarefaIdProva)',
      'idx_tarefa_concluida': '$tableTarefa($colTarefaConcluida)',
      'idx_prova_usuario': '$tableProva($colIdUsuario)',
      'idx_prova_materia': '$tableProva($colProvaIdMateria)',
      'idx_documento_prova': '$tableDocumento($colDocumentoIdProva)',
      'idx_documento_usuario': '$tableDocumento($colIdUsuario)',
      'idx_documento_status': '$tableDocumento($colDocumentoStatus)',
      'idx_documento_data': '$tableDocumento($colDocumentoDataCriacao)',
      'idx_materia_status': '$tableMateria($colMateriaStatus)',
      'idx_nota_materia': '$tableNota($colNotaIdMateria)',
      'idx_nota_prova': '$tableNota($colNotaIdProva)',
      'idx_nota_usuario': '$tableNota($colIdUsuario)',
    };

    for (final entry in indexes.entries) {
      await _tryExecute(
        db,
        'CREATE INDEX IF NOT EXISTS ${entry.key} ON ${entry.value}',
      );
    }
  }

  /// Garante que TODAS as colunas existam — protege bancos de dados antigos
  Future<void> _ensureAllColumnsExist(Database db) async {
    // Tarefa
    await _addColIfMissing(db, tableDocumento, colDocumentoIdTarefa, 'INTEGER');
    await _addColIfMissing(db, tableTarefa, colTarefaIdDocumento, 'INTEGER');
    await _addColIfMissing(db, tableTarefa, colTarefaIdProva, 'INTEGER');
    await _addColIfMissing(db, tableTarefa, colTarefaDataCriacao, 'TEXT');
    await _addColIfMissing(db, tableTarefa, colTarefaDataEntrega, 'TEXT');
    await _addColIfMissing(db, tableTarefa, colTarefaDataConclusao, 'TEXT');
    await _addColIfMissing(
      db,
      tableTarefa,
      colTarefaPrioridade,
      "TEXT DEFAULT 'media'",
    );
    // Materia
    await _addColIfMissing(db, tableMateria, colMateriaIcone, 'INTEGER');
    await _addColIfMissing(db, tableMateria, colIdUsuario, 'TEXT');

    // Materia
    await _addColIfMissing(db, tableMateria, colIdUsuario, 'TEXT');

    // Prova
    await _addColIfMissing(db, tableProva, colProvaIdDocumento, 'INTEGER');
    await _addColIfMissing(db, tableProva, colIdUsuario, 'TEXT');
    await _addColIfMissing(db, tableProva, colProvaDataCriacao, 'TEXT');
    await _addColIfMissing(db, tableProva, colProvaDataProva, 'TEXT');
    await _addColIfMissing(db, tableProva, colProvaNota, 'REAL');
    await _addColIfMissing(db, tableProva, colProvaPeso, 'REAL DEFAULT 1.0');

    // Documento
    await _addColIfMissing(db, tableDocumento, colIdUsuario, 'TEXT');
    await _addColIfMissing(db, tableDocumento, colDocumentoIdProva, 'INTEGER');

    // Cria tabela nota se não existir (bancos antigos)
    await _tryExecute(db, '''
      CREATE TABLE IF NOT EXISTS $tableNota(
        $colNotaId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colNotaIdMateria INTEGER NOT NULL,
        $colNotaDescricao TEXT NOT NULL,
        $colNotaValor REAL NOT NULL,
        $colNotaPeso REAL DEFAULT 1.0,
        $colNotaTipo TEXT DEFAULT 'prova',
        $colNotaData TEXT,
        $colIdUsuario TEXT,
        FOREIGN KEY($colNotaIdMateria) REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
      )
    ''');

    await _tryExecute(
      db,
      'CREATE INDEX IF NOT EXISTS idx_nota_materia ON $tableNota($colNotaIdMateria)',
    );
    await _tryExecute(
      db,
      'CREATE INDEX IF NOT EXISTS idx_nota_usuario ON $tableNota($colIdUsuario)',
    );
    await _addColIfMissing(db, tableNota, colNotaIdProva, 'INTEGER');
    await _tryExecute(
      db,
      'CREATE INDEX IF NOT EXISTS idx_nota_prova ON $tableNota($colNotaIdProva)',
    );
  }

  Future<void> _addColIfMissing(
    Database db,
    String table,
    String col,
    String type,
  ) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final exists = cols.any((c) => c['name']?.toString() == col);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
      }
    } catch (_) {}
  }

  Future<void> _tryExecute(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {}
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        await _tryExecute(db, '''
          CREATE TABLE IF NOT EXISTS $tableDocumento(
            $colDocumentoId INTEGER PRIMARY KEY AUTOINCREMENT,
            $colDocumentoTitulo TEXT NOT NULL,
            $colDocumentoTipo TEXT,
            $colDocumentoCaminho TEXT NOT NULL,
            $colDocumentoNomeArquivo TEXT NOT NULL,
            $colDocumentoDescricao TEXT,
            $colDocumentoResumo TEXT,
            $colDocumentoTopicos TEXT,
            $colDocumentoSugeridos TEXT,
            $colDocumentoQuestoes TEXT,
            $colDocumentoRespostas TEXT,
            $colDocumentoStatus TEXT DEFAULT 'pendente',
            $colDocumentoErro TEXT,
            $colDocumentoDataCriacao TEXT NOT NULL
          )
        ''');
      }
      if (oldVersion < 3) {
        await _addColIfMissing(db, tableTarefa, colTarefaDataCriacao, 'TEXT');
        await _addColIfMissing(db, tableTarefa, colTarefaDataEntrega, 'TEXT');
        await _addColIfMissing(db, tableTarefa, colTarefaDataConclusao, 'TEXT');
      }
      if (oldVersion < 4) {
        await _tryExecute(db, '''
          CREATE TABLE IF NOT EXISTS $tableProva(
            $colProvaId INTEGER PRIMARY KEY AUTOINCREMENT,
            $colProvaTitulo TEXT NOT NULL,
            $colProvaDescricao TEXT,
            $colProvaDataCriacao TEXT,
            $colProvaDataProva TEXT,
            $colProvaNota REAL,
            $colProvaPeso REAL DEFAULT 1.0,
            $colProvaRealizada INTEGER DEFAULT 0,
            $colProvaIdMateria INTEGER NOT NULL,
            FOREIGN KEY($colProvaIdMateria) REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
          )
        ''');
      }
      if (oldVersion < 5) {
        await _addColIfMissing(
          db,
          tableTarefa,
          colTarefaIdDocumento,
          'INTEGER',
        );
        await _addColIfMissing(db, tableProva, colProvaIdDocumento, 'INTEGER');
      }
      if (oldVersion < 6) {
        await _addColIfMissing(db, tableMateria, colIdUsuario, 'TEXT');
        await _addColIfMissing(db, tableTarefa, colIdUsuario, 'TEXT');
        await _addColIfMissing(db, tableProva, colIdUsuario, 'TEXT');
        await _addColIfMissing(db, tableDocumento, colIdUsuario, 'TEXT');
      }
      if (oldVersion < 7) {
        await _addColIfMissing(
          db,
          tableTarefa,
          colTarefaPrioridade,
          "TEXT DEFAULT 'media'",
        );
      }
      if (oldVersion < 8) {
        await _addColIfMissing(db, tableProva, colProvaIdDocumento, 'INTEGER');
        await _addColIfMissing(db, tableProva, colProvaDataCriacao, 'TEXT');
        await _addColIfMissing(db, tableProva, colProvaNota, 'REAL');
      }
      if (oldVersion < 9) {
        // Adiciona tabela de notas independentes
        await _tryExecute(db, '''
          CREATE TABLE IF NOT EXISTS $tableNota(
            $colNotaId INTEGER PRIMARY KEY AUTOINCREMENT,
            $colNotaIdMateria INTEGER NOT NULL,
            $colNotaDescricao TEXT NOT NULL,
            $colNotaValor REAL NOT NULL,
            $colNotaPeso REAL DEFAULT 1.0,
            $colNotaTipo TEXT DEFAULT 'prova',
            $colNotaData TEXT,
            $colNotaIdProva INTEGER,
            $colIdUsuario TEXT,
            FOREIGN KEY($colNotaIdMateria) REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
          )
        ''');
        await _tryExecute(
          db,
          'CREATE INDEX IF NOT EXISTS idx_nota_materia ON $tableNota($colNotaIdMateria)',
        );
        await _tryExecute(
          db,
          'CREATE INDEX IF NOT EXISTS idx_nota_usuario ON $tableNota($colIdUsuario)',
        );
      }

      if (oldVersion < 10) {
        await _addColIfMissing(db, tableTarefa, colTarefaIdProva, 'INTEGER');
        await _addColIfMissing(
          db,
          tableProva,
          colProvaPeso,
          'REAL DEFAULT 1.0',
        );
        await _addColIfMissing(
          db,
          tableDocumento,
          colDocumentoIdProva,
          'INTEGER',
        );
      }

      if (oldVersion < 11) {
        await _addColIfMissing(db, tableNota, colNotaIdProva, 'INTEGER');
      }

      if (oldVersion < 12) {
        await _addColIfMissing(db, tableMateria, colMateriaIcone, 'INTEGER');
      }

      if (oldVersion < 13) {
        await _addColIfMissing(
          db,
          tableDocumento,
          colDocumentoIdTarefa,
          'INTEGER',
        );
      }

      // Sempre garante os índices
      await _createAllIndexes(db);
    } catch (e) {
      throw Exception('Erro no upgrade do banco: $e');
    }
  }

  bool get isOpen => _database != null && _database!.isOpen;

  Future<String> getDbPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<int> getTotalTarefas() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as total FROM $tableTarefa');
    return (r.first['total'] as int?) ?? 0;
  }

  Future<int> getTotalMaterias() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as total FROM $tableMateria');
    return (r.first['total'] as int?) ?? 0;
  }

  Future<void> resetDatabase() async {
    await close();
    final path = await getDbPath();
    await deleteDatabase(path);
    _database = null;
  }
}
