import '../database/database_helper.dart';
import '../models/tarefa.dart';

class TarefaService {

  Future<int> inserirTarefa(
      Tarefa tarefa) async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    return await db.insert(
      'tarefa',
      tarefa.toMap(),
    );
  }

  Future<List<Tarefa>>
      buscarPorMateria(
          int idMateria) async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    final result =
        await db.query(
      'tarefa',
      where: 'id_materia = ?',
      whereArgs: [idMateria],
    );

    return result
        .map(
          (e) =>
              Tarefa.fromMap(e),
        )
        .toList();
  }

  Future<int> atualizarTarefa(
      Tarefa tarefa) async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    return await db.update(
      'tarefa',
      tarefa.toMap(),
      where: 'id = ?',
      whereArgs: [tarefa.id],
    );
  }

  Future<int> removerTarefa(
      int id) async {

    final db =
        await DatabaseHelper
            .instance
            .database;

    return await db.delete(
      'tarefa',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}