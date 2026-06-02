class Tarefa {
  int? id;
  String titulo;
  String descricao;
  bool concluida;
  int idMateria;

  Tarefa({
    this.id,
    required this.titulo,
    required this.descricao,
    required this.concluida,
    required this.idMateria,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'concluida': concluida ? 1 : 0,
      'id_materia': idMateria,
    };
  }

  factory Tarefa.fromMap(
      Map<String, dynamic> map) {
    return Tarefa(
      id: map['id'],
      titulo: map['titulo'],
      descricao: map['descricao'],
      concluida: map['concluida'] == 1,
      idMateria: map['id_materia'],
    );
  }
}