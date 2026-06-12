import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Classe responsável pelo gerenciamento do banco de dados
///
/// Implementa o padrão Singleton para garantir uma única instância
/// do banco de dados em toda a aplicação
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  // Constantes para configuração do banco
  static const String _dbName = 'studyflow.db';
  static const int _dbVersion = 7;

  // Tabelas
  static const String tableMateria = 'materia';
  static const String tableTarefa = 'tarefa';
  static const String tableProva = 'prova';
  static const String tableDocumento = 'documento';

  // Coluna comum multi-usuário
  static const String colIdUsuario = 'id_usuario';

  // Colunas de materia

  static const String colMateriaId = 'id';
  static const String colMateriaNome = 'nome';
  static const String colMateriaProfessor = 'professor';
  static const String colMateriaCor = 'cor';
  static const String colMateriaHorario = 'horario';
  static const String colMateriaMetaHoras = 'meta_horas';
  static const String colMateriaStatus = 'status';

  // Colunas de tarefa
  // Coluna comum multi-usuário
  static const String colTarefaId = 'id';
  static const String colTarefaTitulo = 'titulo';
  static const String colTarefaDescricao = 'descricao';
  static const String colTarefaConcluida = 'concluida';
  static const String colTarefaIdMateria = 'id_materia';
  static const String colTarefaDataCriacao = 'data_criacao';
  static const String colTarefaDataEntrega = 'data_entrega';
  static const String colTarefaDataConclusao = 'data_conclusao';
  static const String colTarefaIdDocumento = 'id_documento';
  static const String colTarefaPrioridade = 'prioridade';

  // Colunas de prova
  static const String colProvaId = 'id';
  static const String colProvaTitulo = 'titulo';
  static const String colProvaDescricao = 'descricao';
  static const String colProvaDataCriacao = 'data_criacao';
  static const String colProvaDataProva = 'data_prova';
  static const String colProvaNota = 'nota';
  static const String colProvaRealizada = 'realizada';
  static const String colProvaIdMateria = 'id_materia';
  static const String colProvaIdDocumento = 'id_documento';

  // Colunas de documento
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

  DatabaseHelper._init();

  /// Retorna a instância do banco de dados
  ///
  /// Inicializa o banco se ainda não foi feito
  /// Garante uma única conexão durante toda a vida da aplicação
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB();

    return _database!;
  }

  /// Inicializa o banco de dados
  ///
  /// Cria o arquivo do banco e estabelece a conexão
  /// Lança exceção se houver erro na inicialização
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

      await _ensureTarefaTableSchema(db);

      return db;
    } catch (e) {
      throw Exception('Erro ao inicializar banco de dados: $e');
    }
  }

  /// Configura o banco de dados antes da criação/upgrade
  ///
  /// Ativa suporte a foreign keys para garantir integridade referencial
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Cria as tabelas do banco de dados na primeira execução
  ///
  /// Define o schema inicial de todas as tabelas
  /// Lança exceção se houver erro na criação
  Future<void> _createDB(Database db, int version) async {
    try {
      // Criar tabela materia
      await db.execute('''
  CREATE TABLE $tableMateria(
    $colMateriaId INTEGER PRIMARY KEY AUTOINCREMENT,
    $colMateriaNome TEXT NOT NULL UNIQUE,
    $colMateriaProfessor TEXT,
    $colMateriaCor INTEGER,
    $colMateriaHorario TEXT,
    $colMateriaMetaHoras REAL DEFAULT 0,
    $colMateriaStatus TEXT DEFAULT 'ativa',
    $colIdUsuario TEXT
  )
''');

      // Criar tabela tarefa
      await db.execute('''
        CREATE TABLE $tableTarefa(
          $colTarefaId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colTarefaTitulo TEXT NOT NULL,
          $colTarefaDescricao TEXT,
          $colTarefaConcluida INTEGER DEFAULT 0,
          $colTarefaIdMateria INTEGER NOT NULL,
          $colTarefaIdDocumento INTEGER,
          $colTarefaDataCriacao TEXT,
          $colTarefaDataEntrega TEXT,
          $colTarefaDataConclusao TEXT,
          $colTarefaPrioridade TEXT DEFAULT 'media',
          $colIdUsuario TEXT,
          FOREIGN KEY($colTarefaIdMateria)
            REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
        )
      ''');

      // Criar tabela documento
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
    $colIdUsuario TEXT
  )
''');
      // Criar tabela prova
      await db.execute('''
  CREATE TABLE $tableProva(
    $colProvaId INTEGER PRIMARY KEY AUTOINCREMENT,
    $colProvaTitulo TEXT NOT NULL,
    $colProvaDescricao TEXT,
    $colProvaDataCriacao TEXT,
    $colProvaDataProva TEXT,
    $colProvaNota REAL,
    $colProvaRealizada INTEGER DEFAULT 0,
    $colProvaIdMateria INTEGER NOT NULL,
    $colIdUsuario TEXT,
    FOREIGN KEY($colProvaIdMateria)
      REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
  )
''');

      // Criar índices para melhorar performance
      await db.execute(
        'CREATE INDEX idx_materia_usuario ON $tableMateria($colIdUsuario)',
      );
      await db.execute(
        'CREATE INDEX idx_tarefa_usuario ON $tableTarefa($colIdUsuario)',
      );
      await db.execute(
        'CREATE INDEX idx_prova_usuario ON $tableProva($colIdUsuario)',
      );
      await db.execute(
        'CREATE INDEX idx_documento_usuario ON $tableDocumento($colIdUsuario)',
      );
      await db.execute(
        'CREATE INDEX idx_tarefa_materia ON $tableTarefa($colTarefaIdMateria)',
      );
      await db.execute(
        'CREATE INDEX idx_materia_status ON $tableMateria($colMateriaStatus)',
      );
      await db.execute(
        'CREATE INDEX idx_tarefa_concluida ON $tableTarefa($colTarefaConcluida)',
      );
      await db.execute(
        'CREATE INDEX idx_prova_materia ON $tableProva($colProvaIdMateria)',
      );
      await db.execute(
        'CREATE INDEX idx_documento_status ON $tableDocumento($colDocumentoStatus)',
      );
      await db.execute(
        'CREATE INDEX idx_documento_data_criacao ON $tableDocumento($colDocumentoDataCriacao)',
      );
    } catch (e) {
      throw Exception('Erro ao criar tabelas: $e');
    }
  }

  Future<void> _ensureTarefaTableSchema(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($tableTarefa)');
      final existingColumns = columns
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();

      final missingColumns = <String, String>{};
      if (!existingColumns.contains(colTarefaIdDocumento)) {
        missingColumns[colTarefaIdDocumento] = 'INTEGER';
      }
      if (!existingColumns.contains(colTarefaDataCriacao)) {
        missingColumns[colTarefaDataCriacao] = 'TEXT';
      }
      if (!existingColumns.contains(colTarefaDataEntrega)) {
        missingColumns[colTarefaDataEntrega] = 'TEXT';
      }
      if (!existingColumns.contains(colTarefaDataConclusao)) {
        missingColumns[colTarefaDataConclusao] = 'TEXT';
      }
      if (!existingColumns.contains(colTarefaPrioridade)) {
        missingColumns[colTarefaPrioridade] = "TEXT DEFAULT 'media'";
      }
      if (!existingColumns.contains(colIdUsuario)) {
        missingColumns[colIdUsuario] = 'TEXT';
      }

      for (final entry in missingColumns.entries) {
        await db.execute(
          'ALTER TABLE $tableTarefa ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    } catch (e) {
      throw Exception('Erro ao assegurar schema da tabela tarefa: $e');
    }
  }

  /// Atualiza o schema do banco de dados para versões posteriores
  ///
  /// Implementa migrations quando a versão do banco mudar
  /// Lança exceção se houver erro na atualização
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < newVersion) {
        if (oldVersion < 2) {
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
              $colDocumentoDataCriacao TEXT NOT NULL
            )
          ''');

          await db.execute(
            'CREATE INDEX idx_documento_status ON $tableDocumento($colDocumentoStatus)',
          );
          await db.execute(
            'CREATE INDEX idx_documento_data_criacao ON $tableDocumento($colDocumentoDataCriacao)',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $tableTarefa ADD COLUMN $colTarefaDataCriacao TEXT',
          );
          await db.execute(
            'ALTER TABLE $tableTarefa ADD COLUMN $colTarefaDataEntrega TEXT',
          );
          await db.execute(
            'ALTER TABLE $tableTarefa ADD COLUMN $colTarefaDataConclusao TEXT',
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE $tableProva(
              $colProvaId INTEGER PRIMARY KEY AUTOINCREMENT,
              $colProvaTitulo TEXT NOT NULL,
              $colProvaDescricao TEXT,
              $colProvaDataCriacao TEXT,
              $colProvaDataProva TEXT,
              $colProvaNota REAL,
              $colProvaRealizada INTEGER DEFAULT 0,
              $colProvaIdMateria INTEGER NOT NULL,
              FOREIGN KEY($colProvaIdMateria)
                REFERENCES $tableMateria($colMateriaId) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_prova_materia ON $tableProva($colProvaIdMateria)',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE $tableTarefa ADD COLUMN $colTarefaIdDocumento INTEGER',
          );
          await db.execute(
            'ALTER TABLE $tableProva ADD COLUMN $colProvaIdDocumento INTEGER',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE $tableMateria ADD COLUMN $colIdUsuario TEXT',
          );
          await db.execute(
            'ALTER TABLE $tableTarefa ADD COLUMN $colIdUsuario TEXT',
          );
          await db.execute(
            'ALTER TABLE $tableProva ADD COLUMN $colIdUsuario TEXT',
          );
          await db.execute(
            'ALTER TABLE $tableDocumento ADD COLUMN $colIdUsuario TEXT',
          );

          await db.execute(
            'CREATE INDEX idx_materia_usuario ON $tableMateria($colIdUsuario)',
          );
          await db.execute(
            'CREATE INDEX idx_tarefa_usuario ON $tableTarefa($colIdUsuario)',
          );
          await db.execute(
            'CREATE INDEX idx_prova_usuario ON $tableProva($colIdUsuario)',
          );
          await db.execute(
            'CREATE INDEX idx_documento_usuario ON $tableDocumento($colIdUsuario)',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            "ALTER TABLE $tableTarefa ADD COLUMN $colTarefaPrioridade TEXT DEFAULT 'media'",
          );
        }
      }
    } catch (e) {
      throw Exception('Erro ao fazer upgrade do banco de dados: $e');
    }
  }

  /// Verifica se o banco de dados está pronto para uso
  ///
  /// Retorna true se a conexão está ativa
  bool get isOpen {
    return _database != null && _database!.isOpen;
  }

  /// Retorna o caminho do arquivo do banco de dados
  ///
  /// Útil para debug e backup
  Future<String> getDbPath() async {
    try {
      final dbPath = await getDatabasesPath();
      return join(dbPath, _dbName);
    } catch (e) {
      throw Exception('Erro ao obter caminho do banco: $e');
    }
  }

  /// Fecha a conexão com o banco de dados
  ///
  /// Deve ser chamado quando a aplicação está siendo encerrada
  /// Libera recursos do banco
  Future<void> close() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
    } catch (e) {
      throw Exception('Erro ao fechar banco de dados: $e');
    }
  }

  /// Executa uma transação com múltiplas operações
  ///
  /// Garante atomicidade: todas as operações são executadas ou nenhuma é
  /// Útil para operações que dependem uma da outra
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    try {
      final db = await database;
      return await db.transaction(action);
    } catch (e) {
      throw Exception('Erro ao executar transação: $e');
    }
  }

  /// Retorna o número total de tarefas no banco
  ///
  /// Útil para estatísticas
  Future<int> getTotalTarefas() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as total FROM $tableTarefa',
      );
      return (result.first['total'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Erro ao contar tarefas: $e');
    }
  }

  /// Retorna o número total de matérias no banco
  ///
  /// Útil para estatísticas
  Future<int> getTotalMaterias() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as total FROM $tableMateria',
      );
      return (result.first['total'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Erro ao contar matérias: $e');
    }
  }

  /// Reseta o banco de dados (usa com cuidado!)
  ///
  /// Remove todas as tabelas e as recria
  /// Útil apenas para testes ou reset completo da aplicação
  Future<void> resetDatabase() async {
    try {
      await close();
      final dbPath = await getDbPath();
      await deleteDatabase(dbPath);
      _database = null;
    } catch (e) {
      throw Exception('Erro ao resetar banco de dados: $e');
    }
  }
}
