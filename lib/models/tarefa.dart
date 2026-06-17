/// Modelo que representa uma Tarefa/Atividade
class Tarefa {
  int? id;
  String titulo;
  String descricao;
  bool concluida;
  final int idMateria;
  DateTime? dataCriacao;
  DateTime? dataEntrega;
  DateTime? dataConclusao;
  int? documentoId;
  String? idUsuario;
  String prioridade;

  Tarefa({
    this.id,
    required this.titulo,
    required this.descricao,
    required this.concluida,
    required this.idMateria,
    this.dataCriacao,
    this.dataEntrega,
    this.dataConclusao,
    this.documentoId,
    this.idUsuario,
    this.prioridade = 'media',
  }) : assert(titulo.isNotEmpty, 'O título da tarefa não pode estar vazio');

  /// Converte o objeto Tarefa para um Map para salvar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo.trim(),
      'descricao': descricao.trim(),
      'concluida': concluida ? 1 : 0,
      'id_materia': idMateria,
      'data_criacao': dataCriacao?.toIso8601String(),
      'data_entrega': dataEntrega?.toIso8601String(),
      'data_conclusao': dataConclusao?.toIso8601String(),
      'id_documento': documentoId,
      'id_usuario': idUsuario,
      'prioridade': prioridade,
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
      dataCriacao: map['data_criacao'] != null ? DateTime.parse(map['data_criacao'] as String) : null,
      dataEntrega: map['data_entrega'] != null ? DateTime.parse(map['data_entrega'] as String) : null,
      dataConclusao: map['data_conclusao'] != null ? DateTime.parse(map['data_conclusao'] as String) : null,
      documentoId: map['id_documento'] as int?,
      idUsuario: map['id_usuario'] as String?,
      prioridade: (map['prioridade'] ?? 'media').toString(),
    );
  }

  @override
  String toString() =>
      'Tarefa(id: $id, titulo: $titulo, concluida: $concluida, dataEntrega: $dataEntrega, prioridade: $prioridade)';

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
