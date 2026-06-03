/// Modelo que representa uma Tarefa/Atividade
class Tarefa {
  final int? id;
  String titulo;
  String descricao;
  bool concluida;
  final int idMateria;

  Tarefa({
    this.id,
    required this.titulo,
    required this.descricao,
    required this.concluida,
    required this.idMateria,
  }) : assert(titulo.isNotEmpty, 'O título da tarefa não pode estar vazio');

  /// Converte o objeto Tarefa para um Map para salvar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo.trim(),
      'descricao': descricao.trim(),
      'concluida': concluida ? 1 : 0,
      'id_materia': idMateria,
    };
  }

  /// Cria uma Tarefa a partir de um Map do banco de dados
  factory Tarefa.fromMap(Map<String, dynamic> map) {
    return Tarefa(
      id: map['id'] as int?,
      titulo: (map['titulo'] ?? '').toString().trim(),
      descricao: (map['descricao'] ?? '').toString().trim(),
      concluida: (map['concluida'] as int? ?? 0) == 1,
      idMateria: map['id_materia'] as int,
    );
  }

  @override
  String toString() =>
      'Tarefa(id: $id, titulo: $titulo, concluida: $concluida)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tarefa &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          titulo == other.titulo;

  @override
  int get hashCode => id.hashCode ^ titulo.hashCode;
}
