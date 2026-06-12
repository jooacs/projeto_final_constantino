import 'package:flutter/material.dart';

/// Modelo que representa uma Matéria/Disciplina
class Materia {
  final int? id;
  String nome;
  String professor;
  Color cor;
  String horario;
  double metaHoras;
  String status;
  String? idUsuario;

  Materia({
    this.id,
    required this.nome,
    required this.professor,
    required this.cor,
    this.horario = '',
    this.metaHoras = 0,
    this.status = 'ativa',
    this.idUsuario,
  }) : assert(nome.isNotEmpty, 'O nome da matéria não pode estar vazio');

  /// Converte o objeto Materia para um Map para salvar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome.trim(),
      'professor': professor.trim(),
      'cor': cor.value,
      'horario': horario.trim(),
      'meta_horas': metaHoras,
      'status': status.trim(),
      'id_usuario': idUsuario,
    };
  }

  /// Cria uma Materia a partir de um Map do banco de dados
  factory Materia.fromMap(Map<String, dynamic> map) {
    return Materia(
      id: map['id'] as int?,
      nome: (map['nome'] ?? '').toString().trim(),
      professor: (map['professor'] ?? '').toString().trim(),
      cor: Color(map['cor'] as int? ?? Colors.blue.value),
      horario: (map['horario'] ?? '').toString().trim(),
      metaHoras: ((map['meta_horas'] ?? 0) as num).toDouble(),
      status: (map['status'] ?? 'ativa').toString().trim(),
      idUsuario: map['id_usuario'] as String?,
    );
  }

  @override
  String toString() => 'Materia(id: $id, nome: $nome, professor: $professor)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Materia &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nome == other.nome;

  @override
  int get hashCode => id.hashCode ^ nome.hashCode;
}
