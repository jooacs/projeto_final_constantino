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
  int? idProva; // NOVO: vincula o resumo/quiz a uma prova específica
  String? idUsuario;
  int? idTarefa;

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
    this.idProva,
    this.idUsuario,
    this.idTarefa,
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
      'id_prova': idProva,
      colIdUsuario: idUsuario,
      'id_tarefa': idTarefa,
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
      idProva: map['id_prova'] as int?,
      idUsuario: map[colIdUsuario] as String?,
      idTarefa: map['id_tarefa'] as int?,
    );
  }
}