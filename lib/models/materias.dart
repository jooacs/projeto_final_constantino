import 'package:flutter/material.dart';

class Materia {
  int? id;
  String nome;
  String professor;
  Color cor;
  String horario;
  double metaHoras;
  String status;

  Materia({
    this.id,
    required this.nome,
    required this.professor,
    required this.cor,
    this.horario = '',
    this.metaHoras = 0,
    this.status = 'ativa',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'professor': professor,
      'cor': cor.value,
      'horario': horario,
      'meta_horas': metaHoras,
      'status': status,
    };
  }

  factory Materia.fromMap(
    Map<String, dynamic> map,
  ) {
    return Materia(
      id: map['id'],
      nome: map['nome'],
      professor: map['professor'],
      cor: Color(map['cor']),
      horario: map['horario'],
      metaHoras: map['meta_horas'],
      status: map['status'],
    );
  }
}