import '../database/database_helper.dart';
import '../database/db_constants.dart';
import '../models/documento.dart';

class DocumentoService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertDocumento(Documento documento) async {
    final db = await _dbHelper.database;
    return await db.insert(tableDocumento, documento.toMap());
  }

  Future<List<Documento>> getDocumentos() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDocumento,
      orderBy: '$colDocumentoDataCriacao DESC',
    );
    return List.generate(maps.length, (i) {
      return Documento.fromMap(maps[i]);
    });
  }

  Future<int> deleteDocumento(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      tableDocumento,
      where: '$colDocumentoId = ?',
      whereArgs: [id],
    );
  }
}
