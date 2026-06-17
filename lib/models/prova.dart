/// Modelo que representa uma Prova
class Prova {
  int? id;
  String titulo;
  String descricao;
  DateTime? dataCriacao;
  DateTime? dataProva;
  double? nota;
  bool realizada;
  final int idMateria;
  int? documentoId;
  String? idUsuario;

  Prova({
    this.id,
    required this.titulo,
    required this.descricao,
    this.dataCriacao,
    this.dataProva,
    this.nota,
    required this.realizada,
    required this.idMateria,
    this.documentoId,
    this.idUsuario,
  }) : assert(titulo.isNotEmpty, 'O título da prova não pode estar vazio');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo.trim(),
      'descricao': descricao.trim(),
      'data_criacao': dataCriacao?.toIso8601String(),
      'data_prova': dataProva?.toIso8601String(),
      'nota': nota,
      'realizada': realizada ? 1 : 0,
      'id_materia': idMateria,
      'id_documento': documentoId,
      'id_usuario': idUsuario,
    };
  }

  factory Prova.fromMap(Map<String, dynamic> map) {
    return Prova(
      id: map['id'] as int?,
      titulo: (map['titulo'] ?? '').toString().trim(),
      descricao: (map['descricao'] ?? '').toString().trim(),
      dataCriacao: map['data_criacao'] != null ? DateTime.parse(map['data_criacao'] as String) : null,
      dataProva: map['data_prova'] != null ? DateTime.parse(map['data_prova'] as String) : null,
      nota: map['nota'] as double?,
      realizada: (map['realizada'] as int? ?? 0) == 1,
      idMateria: map['id_materia'] as int,
      documentoId: map['id_documento'] as int?,
      idUsuario: map['id_usuario'] as String?,
    );
  }

  @override
  String toString() =>
      'Prova(id: $id, titulo: $titulo, realizada: $realizada, dataProva: $dataProva)';
}
