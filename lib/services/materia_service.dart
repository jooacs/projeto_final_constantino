import '../database/database_helper.dart';
import '../models/materia.dart';

/// Serviço responsável por operações CRUD de Matérias
class MateriaService {
  /// Insere uma nova matéria no banco de dados
  ///
  /// Retorna o ID da matéria inserida
  /// Lança exceção se houver erro na inserção
  Future<int> inserirMateria(Materia materia) async {
    try {
      if (materia.nome.trim().isEmpty) {
        throw ArgumentError('O nome da matéria não pode estar vazio');
      }

      final db = await DatabaseHelper.instance.database;

      return await db.insert('materia', materia.toMap());
    } catch (e) {
      throw Exception('Erro ao inserir matéria: $e');
    }
  }

  /// Busca todas as matérias do banco de dados
  ///
  /// Retorna uma lista de Materia ou lista vazia se nenhuma for encontrada
  /// Lança exceção se houver erro na consulta
  Future<List<Materia>> buscarMaterias() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final result = await db.query('materia', orderBy: 'nome ASC');

      return result.map((e) => Materia.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar matérias: $e');
    }
  }

  /// Busca uma matéria específica pelo ID
  ///
  /// Retorna null se nenhuma matéria for encontrada
  /// Lança exceção se houver erro na consulta
  Future<Materia?> buscarMateriaPorId(int id) async {
    try {
      if (id <= 0) {
        throw ArgumentError('ID inválido');
      }

      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'materia',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;

      return Materia.fromMap(result.first);
    } catch (e) {
      throw Exception('Erro ao buscar matéria: $e');
    }
  }

  /// Atualiza uma matéria existente
  ///
  /// Retorna o número de linhas atualizadas
  /// Lança exceção se houver erro na atualização
  Future<int> atualizarMateria(Materia materia) async {
    try {
      if (materia.id == null || materia.id! <= 0) {
        throw ArgumentError('ID da matéria inválido');
      }

      if (materia.nome.trim().isEmpty) {
        throw ArgumentError('O nome da matéria não pode estar vazio');
      }

      final db = await DatabaseHelper.instance.database;

      return await db.update(
        'materia',
        materia.toMap(),
        where: 'id = ?',
        whereArgs: [materia.id],
      );
    } catch (e) {
      throw Exception('Erro ao atualizar matéria: $e');
    }
  }

  /// Remove uma matéria do banco de dados
  ///
  /// Também remove todas as tarefas associadas (cascata)
  /// Retorna o número de linhas deletadas
  /// Lança exceção se houver erro na exclusão
  Future<int> removerMateria(int id) async {
    try {
      if (id <= 0) {
        throw ArgumentError('ID inválido');
      }

      final db = await DatabaseHelper.instance.database;

      // Primeiro remove as tarefas associadas
      await db.delete('tarefa', where: 'id_materia = ?', whereArgs: [id]);

      // Depois remove a matéria
      return await db.delete('materia', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erro ao remover matéria: $e');
    }
  }
}
