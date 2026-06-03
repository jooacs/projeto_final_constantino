/// Arquivo com constantes do banco de dados
///
/// Centraliza todas as constantes relacionadas ao banco de dados
/// para evitar repetição e facilitar manutenção

// ============= NOMES DE TABELAS =============
const String tableMateria = 'materia';
const String tableTarefa = 'tarefa';

// ============= COLUNAS DA TABELA MATERIA =============
const String colMateriaId = 'id';
const String colMateriaNome = 'nome';
const String colMateriaProfessor = 'professor';
const String colMateriaCor = 'cor';
const String colMateriaHorario = 'horario';
const String colMateriaMetaHoras = 'meta_horas';
const String colMateriaStatus = 'status';

// ============= COLUNAS DA TABELA TAREFA =============
const String colTarefaId = 'id';
const String colTarefaTitulo = 'titulo';
const String colTarefaDescricao = 'descricao';
const String colTarefaConcluida = 'concluida';
const String colTarefaIdMateria = 'id_materia';

// ============= TABELA DOCUMENTO =============
const String tableDocumento = 'documento';
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

// ============= VALORES PADRÃO =============
const String statusMateriaAtiva = 'ativa';
const String statusMateriaInativa = 'inativa';
const String statusMateriaArquivada = 'arquivada';

const int tarefaConcluida = 1;
const int tarefaPendente = 0;

// ============= CONFIGURAÇÕES DO BANCO =============
const String dbName = 'studyflow.db';
const int dbVersion = 2;
const int dbTimeoutMs = 30000;

// ============= QUERIES ÚTEIS =============
class DbQueries {
  /// Query para contar tarefas concluídas de uma matéria
  static String countTarefasConcluidas(int idMateria) =>
      'SELECT COUNT(*) as total FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ? AND $colTarefaConcluida = 1';

  /// Query para contar tarefas pendentes de uma matéria
  static String countTarefasPendentes(int idMateria) =>
      'SELECT COUNT(*) as total FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ? AND $colTarefaConcluida = 0';

  /// Query para obter progresso de uma matéria (percentual de tarefas concluídas)
  static String getProgressoMateria(int idMateria) =>
      'SELECT '
      '  CAST(SUM(CASE WHEN $colTarefaConcluida = 1 THEN 1 ELSE 0 END) as REAL) / '
      '  COUNT(*) * 100 as progresso '
      'FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ?';

  /// Query para obter todas as matérias com contagem de tarefas
  static String getMaterialWithTaskCount() =>
      'SELECT m.*, '
      '  COUNT(t.$colTarefaId) as task_count, '
      '  SUM(CASE WHEN t.$colTarefaConcluida = 1 THEN 1 ELSE 0 END) as completed_count '
      'FROM $tableMateria m '
      'LEFT JOIN $tableTarefa t ON m.$colMateriaId = t.$colTarefaIdMateria '
      'GROUP BY m.$colMateriaId '
      'ORDER BY m.$colMateriaNome ASC';

  /// Query para obter tarefas agrupadas por status
  static String getTarefasGroupedByStatus(int idMateria) =>
      'SELECT $colTarefaConcluida, COUNT(*) as quantidade '
      'FROM $tableTarefa '
      'WHERE $colTarefaIdMateria = ? '
      'GROUP BY $colTarefaConcluida';

  /// Query para obter informações resumidas do banco
  static String getDatabaseStats() =>
      'SELECT '
      '  (SELECT COUNT(*) FROM $tableMateria) as total_materias, '
      '  (SELECT COUNT(*) FROM $tableTarefa) as total_tarefas, '
      '  (SELECT COUNT(*) FROM $tableTarefa WHERE $colTarefaConcluida = 1) as tarefas_concluidas, '
      '  (SELECT COUNT(*) FROM $tableTarefa WHERE $colTarefaConcluida = 0) as tarefas_pendentes';
}
