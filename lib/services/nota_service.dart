import '../database/database_helper.dart';
import '../models/nota.dart';
import '../models/prova.dart';
import 'auth_service.dart';

class NotaService {
  static const String _table = 'nota';

  Future<int> inserirNota(Nota nota) async {
    try {
      if (nota.descricao.trim().isEmpty) {
        throw ArgumentError('A descrição não pode estar vazia');
      }
      if (nota.valor < 0 || nota.valor > 10) {
        throw ArgumentError('Nota deve ser entre 0 e 10');
      }
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final map = nota.toMap();
      map['id_usuario'] = uid;
      map.remove('id');

      final db = await DatabaseHelper.instance.database;
      return await db.insert(_table, map);
    } catch (e) {
      throw Exception('Erro ao inserir nota: $e');
    }
  }

  Future<List<Nota>> buscarPorMateria(int idMateria) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return [];

      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        _table,
        where: 'id_materia = ? AND id_usuario = ?',
        whereArgs: [idMateria, uid],
        orderBy: 'data ASC, descricao ASC',
      );
      return result.map((e) => Nota.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar notas: $e');
    }
  }

  Future<List<Nota>> buscarTodas() async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return [];

      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        _table,
        where: 'id_usuario = ?',
        whereArgs: [uid],
        orderBy: 'id_materia ASC, data ASC',
      );
      return result.map((e) => Nota.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar todas as notas: $e');
    }
  }

  Future<int> atualizarNota(Nota nota) async {
    try {
      if (nota.id == null) throw ArgumentError('ID da nota inválido');
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = await DatabaseHelper.instance.database;
      return await db.update(
        _table,
        nota.toMap(),
        where: 'id = ? AND id_usuario = ?',
        whereArgs: [nota.id, uid],
      );
    } catch (e) {
      throw Exception('Erro ao atualizar nota: $e');
    }
  }

  Future<int> removerNota(int id) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = await DatabaseHelper.instance.database;
      return await db.delete(
        _table,
        where: 'id = ? AND id_usuario = ?',
        whereArgs: [id, uid],
      );
    } catch (e) {
      throw Exception('Erro ao remover nota: $e');
    }
  }

  Future<int> removerNotasDaMateria(int idMateria) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return 0;

      final db = await DatabaseHelper.instance.database;
      return await db.delete(
        _table,
        where: 'id_materia = ? AND id_usuario = ?',
        whereArgs: [idMateria, uid],
      );
    } catch (e) {
      throw Exception('Erro ao remover notas da matéria: $e');
    }
  }

  /// Calcula a média ponderada de notas de uma matéria
  Future<int> salvarNotaDaProva(Prova prova, double valor) async {
    try {
      if (prova.id == null) throw ArgumentError('ID da prova inválido');
      if (valor < 0 || valor > 10) {
        throw ArgumentError('Nota deve ser entre 0 e 10');
      }
      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Usuário não autenticado');

      final db = await DatabaseHelper.instance.database;
      final existente = await db.query(
        _table,
        where:
            '(id_prova = ? OR (id_prova IS NULL AND id_materia = ? AND descricao = ? AND tipo = ?)) AND id_usuario = ?',
        whereArgs: [
          prova.id,
          prova.idMateria,
          prova.titulo.trim(),
          'prova',
          uid,
        ],
        limit: 1,
      );

      final nota = Nota(
        id: existente.isNotEmpty ? existente.first['id'] as int? : null,
        idMateria: prova.idMateria,
        descricao: prova.titulo,
        valor: valor,
        peso: prova.peso,
        tipo: 'prova',
        data: prova.dataProva ?? DateTime.now(),
        idProva: prova.id,
        idUsuario: uid,
      );
      final map = nota.toMap();
      map.remove('id');

      if (existente.isNotEmpty) {
        return await db.update(
          _table,
          map,
          where: 'id = ? AND id_usuario = ?',
          whereArgs: [nota.id, uid],
        );
      }

      return await db.insert(_table, map);
    } catch (e) {
      throw Exception('Erro ao salvar nota da prova: $e');
    }
  }

  Future<int> removerNotaDaProva(int idProva) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return 0;

      final db = await DatabaseHelper.instance.database;
      return await db.delete(
        _table,
        where: 'id_prova = ? AND id_usuario = ?',
        whereArgs: [idProva, uid],
      );
    } catch (e) {
      throw Exception('Erro ao remover nota da prova: $e');
    }
  }

  Future<double?> calcularMediaMateria(int idMateria) async {
    try {
      final notas = await buscarPorMateria(idMateria);
      if (notas.isEmpty) return null;
      return _calcularMedia(notas);
    } catch (e) {
      return null;
    }
  }

  static double _calcularMedia(List<Nota> notas) {
    if (notas.isEmpty) return 0;
    final totalPeso = notas.fold(0.0, (sum, n) => sum + n.peso);
    if (totalPeso == 0) return 0;
    final somaValores = notas.fold(0.0, (sum, n) => sum + n.valor * n.peso);
    return somaValores / totalPeso;
  }

  static double calcularMediaPonderada(List<Nota> notas) => _calcularMedia(notas);
}
