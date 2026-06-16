/// Modelo que representa uma Nota de uma matéria
class Nota {
  final int? id;
  final int idMateria;
  String descricao; // Ex: P1, P2, Trabalho, Prova Final
  double valor; // 0.0 a 10.0
  double peso; // peso da avaliação (padrão 1.0)
  String tipo; // 'prova', 'trabalho', 'participacao', 'outro'
  DateTime? data;
  int? idProva;
  String? idUsuario;

  Nota({
    this.id,
    required this.idMateria,
    required this.descricao,
    required this.valor,
    this.peso = 1.0,
    this.tipo = 'prova',
    this.data,
    this.idProva,
    this.idUsuario,
  })  : assert(valor >= 0 && valor <= 10, 'Nota deve estar entre 0 e 10'),
        assert(peso > 0, 'Peso deve ser maior que zero');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_materia': idMateria,
      'descricao': descricao.trim(),
      'valor': valor,
      'peso': peso,
      'tipo': tipo,
      'data': data?.toIso8601String(),
      'id_prova': idProva,
      'id_usuario': idUsuario,
    };
  }

  factory Nota.fromMap(Map<String, dynamic> map) {
    return Nota(
      id: map['id'] as int?,
      idMateria: map['id_materia'] as int,
      descricao: (map['descricao'] ?? '').toString().trim(),
      valor: ((map['valor'] ?? 0) as num).toDouble(),
      peso: ((map['peso'] ?? 1.0) as num).toDouble(),
      tipo: (map['tipo'] ?? 'prova').toString(),
      data: map['data'] != null ? DateTime.tryParse(map['data'] as String) : null,
      idProva: map['id_prova'] as int?,
      idUsuario: map['id_usuario'] as String?,
    );
  }

  @override
  String toString() =>
      'Nota(id: $id, idMateria: $idMateria, descricao: $descricao, valor: $valor, peso: $peso)';
}
