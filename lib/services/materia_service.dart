import '../database/database_helper.dart';
import '../models/materia.dart';
import 'auth_service.dart';

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

      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      materia.idUsuario = uid;

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
      final uid = AuthService.currentUserId;
      if (uid == null) return [];
      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'materia',
        where: 'id_usuario = ?',
        whereArgs: [uid],
        orderBy: 'nome ASC',
      );

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
      if (id <= 0) throw ArgumentError('ID inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) return null;

      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'materia',
        where: 'id = ? AND id_usuario = ?',
        whereArgs: [id, uid],
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
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = await DatabaseHelper.instance.database;
      return await db.update(
        'materia',
        materia.toMap(),
        where: 'id = ? AND id_usuario = ?',
        whereArgs: [materia.id, uid],
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
      if (id <= 0) throw ArgumentError('ID inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = await DatabaseHelper.instance.database;
      await db.delete('tarefa', where: 'id_materia = ? AND id_usuario = ?', whereArgs: [id, uid]);
      await db.delete('prova', where: 'id_materia = ? AND id_usuario = ?', whereArgs: [id, uid]);
      return await db.delete('materia', where: 'id = ? AND id_usuario = ?', whereArgs: [id, uid]);
    } catch (e) {
      throw Exception('Erro ao remover matéria: $e');
    }
  }
}
