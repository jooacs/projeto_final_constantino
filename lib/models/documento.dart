import '../database/db_constants.dart';

class Documento {
  int? id;
  String titulo;
  String tipo; // 'resumo' ou 'quiz'
  String caminho;
  String nomeArquivo;
  String? resumo;
  String? questoes; // JSON das questões
  String dataCriacao;
  int? idProva; // NOVO: vincula o resumo/quiz a uma prova específica
  String? idUsuario;

  Documento({
    this.id,
    required this.titulo,
    required this.tipo,
    required this.caminho,
    required this.nomeArquivo,
    this.resumo,
    this.questoes,
    required this.dataCriacao,
    this.idProva,
    this.idUsuario,
  });

  Map<String, dynamic> toMap() {
    return {
      colDocumentoId: id,
      colDocumentoTitulo: titulo,
      colDocumentoTipo: tipo,
      colDocumentoCaminho: caminho,
      colDocumentoNomeArquivo: nomeArquivo,
      colDocumentoResumo: resumo,
      colDocumentoQuestoes: questoes,
      colDocumentoDataCriacao: dataCriacao,
      'id_prova': idProva,
      colIdUsuario: idUsuario,
    };
  }

  factory Documento.fromMap(Map<String, dynamic> map) {
    return Documento(
      id: map[colDocumentoId],
      titulo: map[colDocumentoTitulo],
      tipo: map[colDocumentoTipo],
      caminho: map[colDocumentoCaminho],
      nomeArquivo: map[colDocumentoNomeArquivo],
      resumo: map[colDocumentoResumo],
      questoes: map[colDocumentoQuestoes],
      dataCriacao: map[colDocumentoDataCriacao],
      idProva: map['id_prova'] as int?,
      idUsuario: map[colIdUsuario] as String?,
    );
  }
}