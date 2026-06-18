import '../database/database_helper.dart';
import '../database/db_constants.dart';
import '../models/documento.dart';
import 'auth_service.dart';

class DocumentoService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertDocumento(Documento documento) async {
    final uid = AuthService.currentUserId;
    if (uid == null) throw Exception('Usuário não autenticado');
    documento.idUsuario = uid;

    final db = await _dbHelper.database;
    return await db.insert(tableDocumento, documento.toMap());
  }

  Future<List<Documento>> getDocumentos() async {
    final uid = AuthService.currentUserId;
    if (uid == null) return [];

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDocumento,
      where: '$colIdUsuario = ?',
      whereArgs: [uid],
      orderBy: '$colDocumentoDataCriacao DESC',
    );
    return List.generate(maps.length, (i) => Documento.fromMap(maps[i]));
  }

  Future<int> updateDocumento(Documento documento) async {
    final uid = AuthService.currentUserId;
    if (uid == null) throw Exception('Usuário não autenticado');

    final db = await _dbHelper.database;
    return await db.update(
      tableDocumento,
      documento.toMap(),
      where: '$colDocumentoId = ? AND $colIdUsuario = ?',
      whereArgs: [documento.id, uid],
    );
  }

  Future<List<Documento>> buscarPorTarefa(int idTarefa) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      'documento',
      where: 'id_tarefa = ?',
      whereArgs: [idTarefa],
      orderBy: 'data_criacao DESC',
    );

    return result.map((e) => Documento.fromMap(e)).toList();
  }

  /// Busca todos os documentos vinculados a uma prova específica.
  Future<List<Documento>> buscarPorProva(int idProva) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return [];

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDocumento,
      where: '$colDocumentoIdProva = ? AND $colIdUsuario = ?',
      whereArgs: [idProva, uid],
      orderBy: '$colDocumentoDataCriacao DESC',
    );
    return List.generate(maps.length, (i) => Documento.fromMap(maps[i]));
  }

  Future<int> deleteDocumento(int id) async {
    final uid = AuthService.currentUserId;
    if (uid == null) throw Exception('Usuário não autenticado');

    final db = await _dbHelper.database;
    return await db.delete(
      tableDocumento,
      where: '$colDocumentoId = ? AND $colIdUsuario = ?',
      whereArgs: [id, uid],
    );
  }
}
