import '../database/database_helper.dart';
import '../models/prova.dart';
import 'auth_service.dart';

class ProvaService {
  Future<int> inserirProva(Prova prova) async {
    try {
      if (prova.titulo.trim().isEmpty) {
        throw ArgumentError('O título não pode estar vazio');
      }
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');
      prova.idUsuario = uid;

      final db = await DatabaseHelper.instance.database;
      return await db.insert('prova', prova.toMap());
    } catch (e) {
      throw Exception('Erro ao inserir prova: $e');
    }
  }

  Future<List<Prova>> buscarPorMateria(int idMateria) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return [];

      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'prova',
        where: 'id_materia = ? AND id_usuario = ?',
        whereArgs: [idMateria, uid],
        orderBy: 'realizada ASC, data_prova ASC',
      );
      return result.map((e) => Prova.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar provas: $e');
    }
  }

  Future<List<Prova>> buscarTodas() async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return [];

      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'prova',
        where: 'id_usuario = ?',
        whereArgs: [uid],
        orderBy: 'realizada ASC, data_prova ASC',
      );
      return result.map((e) => Prova.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar todas as provas: $e');
    }
  }

  Future<int> atualizarProva(Prova prova) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = await DatabaseHelper.instance.database;
      return await db.update(
        'prova',
        prova.toMap(),
        where: 'id = ? AND id_usuario = ?',
        whereArgs: [prova.id, uid],
      );
    } catch (e) {
      throw Exception('Erro ao atualizar prova: $e');
    }
  }

  Future<int> removerProva(int id) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = await DatabaseHelper.instance.database;
      return await db.delete('prova', where: 'id = ? AND id_usuario = ?', whereArgs: [id, uid]);
    } catch (e) {
      throw Exception('Erro ao remover prova: $e');
    }
  }
}