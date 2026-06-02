import '../database/database_helper.dart';
import '../models/materias.dart';

class MateriaService {

  // INSERT
  Future<int> inserirMateria(
      Materia materia) async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    return await db.insert(
      'materia',
      materia.toMap(),
    );
  }

  // SELECT
  Future<List<Materia>>
      buscarMaterias() async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    final result =
        await db.query(
      'materia',
    );

    return result
        .map((e) =>
            Materia.fromMap(e))
        .toList();
  }

  // UPDATE
  Future<int> atualizarMateria(
      Materia materia) async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    return await db.update(
      'materia',
      materia.toMap(),
      where: 'id = ?',
      whereArgs: [materia.id],
    );
  }

  // DELETE
  Future<int> removerMateria(
      int id) async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    return await db.delete(
      'materia',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}