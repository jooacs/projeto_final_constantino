import '../database/database_helper.dart';
import '../models/tarefa.dart';

/// Serviço responsável por operações CRUD de Tarefas
class TarefaService {
  /// Insere uma nova tarefa no banco de dados
  ///
  /// Retorna o ID da tarefa inserida
  /// Lança exceção se houver erro na inserção
  Future<int> inserirTarefa(Tarefa tarefa) async {
    try {
      if (tarefa.titulo.trim().isEmpty) {
        throw ArgumentError('O título da tarefa não pode estar vazio');
      }

      if (tarefa.idMateria <= 0) {
        throw ArgumentError('ID da matéria inválido');
      }

      final db = await DatabaseHelper.instance.database;

      return await db.insert('tarefa', tarefa.toMap());
    } catch (e) {
      throw Exception('Erro ao inserir tarefa: $e');
    }
  }

  /// Busca todas as tarefas de uma matéria específica
  ///
  /// Retorna uma lista de Tarefa ou lista vazia se nenhuma for encontrada
  /// Lança exceção se houver erro na consulta
  Future<List<Tarefa>> buscarPorMateria(int idMateria) async {
    try {
      if (idMateria <= 0) {
        throw ArgumentError('ID da matéria inválido');
      }

      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'tarefa',
        where: 'id_materia = ?',
        whereArgs: [idMateria],
        orderBy: 'concluida ASC, titulo ASC',
      );

      return result.map((e) => Tarefa.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar tarefas: $e');
    }
  }

  /// Busca uma tarefa específica pelo ID
  ///
  /// Retorna null se nenhuma tarefa for encontrada
  /// Lança exceção se houver erro na consulta
  Future<Tarefa?> buscarTarefaPorId(int id) async {
    try {
      if (id <= 0) {
        throw ArgumentError('ID inválido');
      }

      final db = await DatabaseHelper.instance.database;

      final result = await db.query('tarefa', where: 'id = ?', whereArgs: [id]);

      if (result.isEmpty) return null;

      return Tarefa.fromMap(result.first);
    } catch (e) {
      throw Exception('Erro ao buscar tarefa: $e');
    }
  }

  /// Busca todas as tarefas não concluídas de uma matéria
  ///
  /// Retorna uma lista de Tarefa não concluídas
  /// Lança exceção se houver erro na consulta
  Future<List<Tarefa>> buscarTarefasPendentes(int idMateria) async {
    try {
      if (idMateria <= 0) {
        throw ArgumentError('ID da matéria inválido');
      }

      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'tarefa',
        where: 'id_materia = ? AND concluida = 0',
        whereArgs: [idMateria],
        orderBy: 'titulo ASC',
      );

      return result.map((e) => Tarefa.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar tarefas pendentes: $e');
    }
  }

  /// Atualiza uma tarefa existente
  ///
  /// Retorna o número de linhas atualizadas
  /// Lança exceção se houver erro na atualização
  Future<int> atualizarTarefa(Tarefa tarefa) async {
    try {
      if (tarefa.id == null || tarefa.id! <= 0) {
        throw ArgumentError('ID da tarefa inválido');
      }

      if (tarefa.titulo.trim().isEmpty) {
        throw ArgumentError('O título da tarefa não pode estar vazio');
      }

      final db = await DatabaseHelper.instance.database;

      return await db.update(
        'tarefa',
        tarefa.toMap(),
        where: 'id = ?',
        whereArgs: [tarefa.id],
      );
    } catch (e) {
      throw Exception('Erro ao atualizar tarefa: $e');
    }
  }

  /// Remove uma tarefa do banco de dados
  ///
  /// Retorna o número de linhas deletadas
  /// Lança exceção se houver erro na exclusão
  Future<int> removerTarefa(int id) async {
    try {
      if (id <= 0) {
        throw ArgumentError('ID inválido');
      }

      final db = await DatabaseHelper.instance.database;

      return await db.delete('tarefa', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erro ao remover tarefa: $e');
    }
  }

  /// Busca o total de tarefas concluídas de uma matéria
  ///
  /// Útil para calcular progresso/estatísticas
  Future<int> contarTarefasConcluidas(int idMateria) async {
    try {
      if (idMateria <= 0) {
        throw ArgumentError('ID da matéria inválido');
      }

      final db = await DatabaseHelper.instance.database;

      final result = await db.rawQuery(
        'SELECT COUNT(*) as total FROM tarefa WHERE id_materia = ? AND concluida = 1',
        [idMateria],
      );

      return (result.first['total'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Erro ao contar tarefas concluídas: $e');
    }
  }
}
