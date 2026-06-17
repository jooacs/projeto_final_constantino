/// Arquivo com constantes do banco de dados
///
/// Centraliza todas as constantes relacionadas ao banco de dados
/// para evitar repetição e facilitar manutenção

// ============= COLUNA COMUM (MULTI-USUÁRIO) =============
const String colIdUsuario = 'id_usuario';

// ============= NOMES DE TABELAS =============
const String tableMateria = 'materia';
const String tableTarefa = 'tarefa';

// ============= COLUNAS DA TABELA MATERIA =============
const String colMateriaId = 'id';
const String colMateriaNome = 'nome';
const String colMateriaProfessor = 'professor';
const String colMateriaCor = 'cor';
const String colMateriaIcone = 'icone';
const String colMateriaHorario = 'horario';
const String colMateriaMetaHoras = 'meta_horas';
const String colMateriaStatus = 'status';

// ============= COLUNAS DA TABELA TAREFA =============
const String colTarefaId = 'id';
const String colTarefaTitulo = 'titulo';
const String colTarefaDescricao = 'descricao';
const String colTarefaConcluida = 'concluida';
const String colTarefaIdMateria = 'id_materia';
const String colTarefaDataCriacao = 'data_criacao';
const String colTarefaDataEntrega = 'data_entrega';
const String colTarefaDataConclusao = 'data_conclusao';
const String colTarefaIdDocumento = 'id_documento';
const String colTarefaIdProva = 'id_prova';
const String colTarefaPrioridade = 'prioridade';

// ============= NÍVEIS DE PRIORIDADE =============
const String prioridadeBaixa = 'baixa';
const String prioridadeMedia = 'media';
const String prioridadeAlta = 'alta';

// ============= TABELA PROVA =============
const String tableProva = 'prova';
const String colProvaId = 'id';
const String colProvaTitulo = 'titulo';
const String colProvaDescricao = 'descricao';
const String colProvaDataCriacao = 'data_criacao';
const String colProvaDataProva = 'data_prova';
const String colProvaNota = 'nota';
const String colProvaPeso = 'peso';
const String colProvaRealizada = 'realizada';
const String colProvaIdMateria = 'id_materia';
const String colProvaIdDocumento = 'id_documento';

// ============= TABELA DOCUMENTO =============
const String tableDocumento = 'documento';
const String colDocumentoId = 'id';
const String colDocumentoTitulo = 'titulo';
const String colDocumentoTipo = 'tipo';
const String colDocumentoCaminho = 'caminho';
const String colDocumentoNomeArquivo = 'nome_arquivo';
const String colDocumentoDescricao = 'descricao';
const String colDocumentoResumo = 'resumo';
const String colDocumentoTopicos = 'topicos';
const String colDocumentoSugeridos = 'sugeridos';
const String colDocumentoQuestoes = 'questoes';
const String colDocumentoRespostas = 'respostas';
const String colDocumentoStatus = 'status';
const String colDocumentoErro = 'erro';
const String colDocumentoDataCriacao = 'data_criacao';
const String colDocumentoIdProva = 'id_prova';

// ============= TABELA NOTA =============
const String tableNota = 'nota';
const String colNotaId = 'id';
const String colNotaIdMateria = 'id_materia';
const String colNotaDescricao = 'descricao';
const String colNotaValor = 'valor';
const String colNotaPeso = 'peso';
const String colNotaTipo = 'tipo';
const String colNotaData = 'data';
const String colNotaIdProva = 'id_prova';

// ============= VALORES PADRÃO =============
const String statusMateriaAtiva = 'ativa';
const String statusMateriaInativa = 'inativa';
const String statusMateriaArquivada = 'arquivada';

const int tarefaConcluida = 1;
const int tarefaPendente = 0;

// ============= CONFIGURAÇÕES DO BANCO =============
const String dbName = 'studyflow.db';
const int dbVersion = 11;
const int dbTimeoutMs = 30000;

// ============= QUERIES ÚTEIS =============
class DbQueries {
  static String countTarefasConcluidas(int idMateria) =>
      'SELECT COUNT(*) as total FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ? AND $colTarefaConcluida = 1 AND $colIdUsuario = ?';

  static String countTarefasPendentes(int idMateria) =>
      'SELECT COUNT(*) as total FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ? AND $colTarefaConcluida = 0 AND $colIdUsuario = ?';

  static String getProgressoMateria(int idMateria) =>
      'SELECT '
      '  CAST(SUM(CASE WHEN $colTarefaConcluida = 1 THEN 1 ELSE 0 END) as REAL) / '
      '  COUNT(*) * 100 as progresso '
      'FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ? AND $colIdUsuario = ?';

  static String getMaterialWithTaskCount() =>
      'SELECT m.*, '
      '  COUNT(t.$colTarefaId) as task_count, '
      '  SUM(CASE WHEN t.$colTarefaConcluida = 1 THEN 1 ELSE 0 END) as completed_count '
      'FROM $tableMateria m '
      'LEFT JOIN $tableTarefa t ON m.$colMateriaId = t.$colTarefaIdMateria '
      'WHERE m.$colIdUsuario = ? '
      'GROUP BY m.$colMateriaId '
      'ORDER BY m.$colMateriaNome ASC';

  static String getTarefasGroupedByStatus(int idMateria) =>
      'SELECT $colTarefaConcluida, COUNT(*) as quantidade '
      'FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ? AND $colIdUsuario = ? '
      'GROUP BY $colTarefaConcluida';

  static String getDatabaseStats() =>
      'SELECT '
      '  (SELECT COUNT(*) FROM $tableMateria WHERE $colIdUsuario = ?) as total_materias, '
      '  (SELECT COUNT(*) FROM $tableTarefa WHERE $colIdUsuario = ?) as total_tarefas, '
      '  (SELECT COUNT(*) FROM $tableTarefa WHERE $colTarefaConcluida = 1 AND $colIdUsuario = ?) as tarefas_concluidas, '
      '  (SELECT COUNT(*) FROM $tableTarefa WHERE $colTarefaConcluida = 0 AND $colIdUsuario = ?) as tarefas_pendentes';
}
