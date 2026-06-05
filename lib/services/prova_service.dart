import '../database/database_helper.dart';
import '../models/prova.dart';

class ProvaService {
  Future<int> inserirProva(Prova prova) async {
    try {
      if (prova.titulo.trim().isEmpty) {
        throw ArgumentError('O título não pode estar vazio');
      }
      final db = await DatabaseHelper.instance.database;
      return await db.insert('prova', prova.toMap());
    } catch (e) {
      throw Exception('Erro ao inserir prova: $e');
    }
  }

  Future<List<Prova>> buscarPorMateria(int idMateria) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'prova',
        where: 'id_materia = ?',
        whereArgs: [idMateria],
        orderBy: 'realizada ASC, data_prova ASC',
      );
      return result.map((e) => Prova.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar provas: $e');
    }
  }

  Future<List<Prova>> buscarTodas() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'prova',
        orderBy: 'realizada ASC, data_prova ASC',
      );
      return result.map((e) => Prova.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar todas as provas: $e');
    }
  }

  Future<int> atualizarProva(Prova prova) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.update(
        'prova',
        prova.toMap(),
        where: 'id = ?',
        whereArgs: [prova.id],
      );
    } catch (e) {
      throw Exception('Erro ao atualizar prova: $e');
    }
  }

  Future<int> removerProva(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.delete('prova', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Erro ao remover prova: $e');
    }
  }
}
