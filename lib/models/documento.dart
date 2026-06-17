import '../database/db_constants.dart';

class Documento {
  int? id;
  String titulo;
  String tipo; // 'resumo' ou 'quiz'
  String caminho;
  String nomeArquivo;
  String? resumo;
  String? questoes; // JSON das questões
  String? respostas; // JSON com acertos, erros, etc
  String dataCriacao;
  String? idUsuario;

  Documento({
    this.id,
    required this.titulo,
    required this.tipo,
    required this.caminho,
    required this.nomeArquivo,
    this.resumo,
    this.questoes,
    this.respostas,
    required this.dataCriacao,
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
      colDocumentoRespostas: respostas,
      colDocumentoDataCriacao: dataCriacao,
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
      respostas: map[colDocumentoRespostas],
      dataCriacao: map[colDocumentoDataCriacao],
      idUsuario: map[colIdUsuario] as String?,
    );
  }
}
