import 'database_helper.dart';
import 'db_constants.dart';
import '../services/auth_service.dart';

/// Classe utilitária com operações comuns de banco de dados
///
/// Fornece métodos reutilizáveis para operações frequentes
class DbUtils {
  /// Obtém estatísticas gerais do banco de dados
  ///
  /// Retorna um Map com informações de contagem de matérias, tarefas, etc.
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) {
        return {
          'total_materias': 0,
          'total_tarefas': 0,
          'tarefas_concluidas': 0,
          'tarefas_pendentes': 0,
        };
      }

      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(DbQueries.getDatabaseStats(), [
        uid,
        uid,
        uid,
        uid,
      ]);

      if (result.isNotEmpty) return result.first;

      return {
        'total_materias': 0,
        'total_tarefas': 0,
        'tarefas_concluidas': 0,
        'tarefas_pendentes': 0,
      };
    } catch (e) {
      throw Exception('Erro ao obter estatísticas: $e');
    }
  }

  /// Obtém o progresso de uma matéria em percentual
  ///
  /// Retorna um valor de 0 a 100 representando o percentual de tarefas concluídas
  /// Retorna 0 se não houver tarefas
  static Future<double> getProgressoMateria(int idMateria) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return 0.0;

      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        DbQueries.getProgressoMateria(idMateria),
        [idMateria, uid],
      );

      if (result.isNotEmpty && result.first['progresso'] != null) {
        return (result.first['progresso'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      throw Exception('Erro ao calcular progresso: $e');
    }
  }

  /// Verifica se existe uma matéria com determinado nome
  ///
  /// Útil para validar duplicatas antes de inserir
  static Future<bool> materiaExists(String nome) async {
    try {
      if (nome.trim().isEmpty) return false;
      final uid = AuthService.currentUserId;
      if (uid == null) return false;

      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        tableMateria,
        where: '$colMateriaNome = ? AND $colIdUsuario = ?',
        whereArgs: [nome.trim(), uid],
      );
      return result.isNotEmpty;
    } catch (e) {
      throw Exception('Erro ao verificar existência de matéria: $e');
    }
  }

  /// Verifica se uma matéria tem tarefas associadas
  ///
  /// Retorna true se houver pelo menos uma tarefa
  static Future<bool> materiaHasTarefas(int idMateria) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return false;

      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        tableTarefa,
        where: '$colTarefaIdMateria = ? AND $colIdUsuario = ?',
        whereArgs: [idMateria, uid],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      throw Exception('Erro ao verificar tarefas: $e');
    }
  }

  /// Obtém o número de tarefas concluídas de uma matéria
  static Future<int> countTarefasConcluidas(int idMateria) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return 0;

      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        DbQueries.countTarefasConcluidas(idMateria),
        [idMateria, uid],
      );
      return (result.first['total'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Erro ao contar tarefas concluídas: $e');
    }
  }

  /// Obtém o número de tarefas pendentes de uma matéria
  static Future<int> countTarefasPendentes(int idMateria) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return 0;

      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        DbQueries.countTarefasPendentes(idMateria),
        [idMateria, uid],
      );
      return (result.first['total'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Erro ao contar tarefas pendentes: $e');
    }
  }

  /// Marca todas as tarefas de uma matéria como concluídas
  ///
  /// Útil para operações em lote
  static Future<int> marcarTodasTarefasConcluidas(int idMateria) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return 0;

      final db = await DatabaseHelper.instance.database;
      return await db.update(
        tableTarefa,
        {colTarefaConcluida: tarefaConcluida},
        where: '$colTarefaIdMateria = ? AND $colIdUsuario = ?',
        whereArgs: [idMateria, uid],
      );
    } catch (e) {
      throw Exception('Erro ao marcar tarefas como concluídas: $e');
    }
  }

  /// Marca todas as tarefas de uma matéria como pendentes
  ///
  /// Útil para operações em lote
  static Future<int> marcarTodasTarefasPendentes(int idMateria) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return 0;

      final db = await DatabaseHelper.instance.database;
      return await db.update(
        tableTarefa,
        {colTarefaConcluida: tarefaPendente},
        where: '$colTarefaIdMateria = ? AND $colIdUsuario = ?',
        whereArgs: [idMateria, uid],
      );
    } catch (e) {
      throw Exception('Erro ao marcar tarefas como pendentes: $e');
    }
  }

  /// Deleta todas as tarefas de uma matéria
  ///
  /// Retorna o número de tarefas deletadas
  static Future<int> deletarTodasTarefas(int idMateria) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return 0;

      final db = await DatabaseHelper.instance.database;
      return await db.delete(
        tableTarefa,
        where: '$colTarefaIdMateria = ? AND $colIdUsuario = ?',
        whereArgs: [idMateria, uid],
      );
    } catch (e) {
      throw Exception('Erro ao deletar tarefas: $e');
    }
  }

  /// Obtém informações detalhadas de uma matéria com contagem de tarefas
  ///
  /// Retorna um Map com dados da matéria e contagem de tarefas
  static Future<Map<String, dynamic>?> getMateriaWithStats(
    int idMateria,
  ) async {
    try {
      if (idMateria <= 0) throw ArgumentError('ID da matéria inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return null;

      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(DbQueries.getMaterialWithTaskCount(), [
        uid,
      ]);

      try {
        return result.firstWhere(
              (m) => m[colMateriaId] == idMateria,
              orElse: () => {},
            )
            as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    } catch (e) {
      throw Exception('Erro ao obter stats da matéria: $e');
    }
  }

  /// Obtém todas as matérias com informações de tarefas
  ///
  /// Retorna lista com task_count e completed_count para cada matéria
  static Future<List<Map<String, dynamic>>> getAllMateriasWithStats() async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return [];

      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(DbQueries.getMaterialWithTaskCount(), [
        uid,
      ]);
      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Erro ao obter materias com stats: $e');
    }
  }

  /// Executa uma query customizada
  ///
  /// Use apenas com queries de apenas leitura
  static Future<List<Map<String, dynamic>>> executeQuery(
    String query, [
    List<dynamic>? args,
  ]) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(query, args);
      return result;
    } catch (e) {
      throw Exception('Erro ao executar query: $e');
    }
  }

  /// Valida a integridade do banco de dados
  ///
  /// Verifica se não há referências órfãs
  static Future<Map<String, dynamic>> validateDatabaseIntegrity() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final orphanedTasks = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $tableTarefa t
        WHERE NOT EXISTS (
          SELECT 1 FROM $tableMateria m WHERE m.$colMateriaId = t.$colTarefaIdMateria
        )
      ''');

      return {
        'isValid': (orphanedTasks.first['count'] as int?) == 0,
        'orphanedTasks': (orphanedTasks.first['count'] as int?) ?? 0,
      };
    } catch (e) {
      throw Exception('Erro ao validar banco: $e');
    }
  }
}
