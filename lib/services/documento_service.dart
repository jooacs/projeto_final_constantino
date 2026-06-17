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