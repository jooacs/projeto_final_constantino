import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/tarefa.dart';
import '../models/prova.dart';
import '../models/materia.dart';
import '../models/documento.dart';
import '../models/questao.dart';
import '../services/tarefa_service.dart';
import '../services/prova_service.dart';
import '../services/materia_service.dart';
import '../services/documento_service.dart';
import 'tela_quiz.dart';

class TelaEstatisticasQuestoes extends StatefulWidget {
  const TelaEstatisticasQuestoes({super.key});

  @override
  State<TelaEstatisticasQuestoes> createState() => _TelaEstatisticasQuestoesState();
}

class _TelaEstatisticasQuestoesState extends State<TelaEstatisticasQuestoes> {
  final TarefaService _tarefaService = TarefaService();
  final ProvaService _provaService = ProvaService();
  final MateriaService _materiaService = MateriaService();
  final DocumentoService _documentoService = DocumentoService();

  bool _isLoading = true;
  String? _errorMessage;
  
  Map<int, Map<String, dynamic>> _statsPorMateria = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final tarefas = await _tarefaService.buscarTodas();
      final provas = await _provaService.buscarTodas();
      final materias = await _materiaService.buscarMaterias();
      final documentos = await _documentoService.getDocumentos();

      Map<int, Map<String, dynamic>> stats = {};

      for (var materia in materias.cast<Materia>()) {
        if (materia.id != null) {
          stats[materia.id!] = {
            'materia': materia,
            'acertos': 0,
            'erros': 0,
            'questoes_erradas': <Questao>[],
          };
        }
      }

      for (var doc in documentos.cast<Documento>()) {
        if (doc.respostas != null) {
          try {
            final Map<String, dynamic> respostasData = jsonDecode(doc.respostas!);
            final int acertos = respostasData['acertos'] ?? 0;
            final int erros = respostasData['erros'] ?? 0;

            if (acertos == 0 && erros == 0) continue;

            int? materiaId;

            // Try to find the document in Tarefas
            try {
              final tarefa = tarefas.cast<Tarefa>().firstWhere((t) => t.documentoId == doc.id);
              materiaId = tarefa.idMateria;
            } catch (_) {}

            // Try to find the document in Provas if not found in Tarefas
            if (materiaId == null) {
              try {
                final prova = provas.cast<Prova>().firstWhere((p) => p.documentoId == doc.id);
                materiaId = prova.idMateria;
              } catch (_) {}
            }

            if (materiaId != null && stats.containsKey(materiaId)) {
              stats[materiaId]!['acertos'] = (stats[materiaId]!['acertos'] as int) + acertos;
              stats[materiaId]!['erros'] = (stats[materiaId]!['erros'] as int) + erros;
              
              // Extract wrong questions
              final List<dynamic>? indicesErrosDynamic = respostasData['indicesErros'];
              if (indicesErrosDynamic != null && indicesErrosDynamic.isNotEmpty && doc.questoes != null) {
                try {
                  final List<int> indicesErros = indicesErrosDynamic.cast<int>();
                  final List<dynamic> questoesJson = jsonDecode(doc.questoes!);
                  for (int indice in indicesErros) {
                    if (indice >= 0 && indice < questoesJson.length) {
                      (stats[materiaId]!['questoes_erradas'] as List<Questao>).add(Questao.fromJson(questoesJson[indice]));
                    }
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      }

      // Remove materias with no answers
      stats.removeWhere((key, value) => value['acertos'] == 0 && value['erros'] == 0);

      setState(() {
        _statsPorMateria = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar estatísticas: $e';
        _isLoading = false;
      });
    }
  }

  void _mostrarOpcoesRevisao() {
    final materiasComErro = _statsPorMateria.values
        .where((data) => (data['questoes_erradas'] as List<Questao>).isNotEmpty)
        .toList();
        
    if (materiasComErro.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem detalhes de questões erradas salvas para revisar! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('O que deseja revisar?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (materiasComErro.length > 1) ...[
                  ListTile(
                    leading: const Icon(Icons.all_inclusive, color: Color(0xFF8B5CF6)),
                    title: const Text('Todas as matérias'),
                    subtitle: Text('${materiasComErro.fold(0, (sum, item) => sum + (item['questoes_erradas'] as List<Questao>).length)} questões no total'),
                    onTap: () {
                      Navigator.pop(context);
                      _iniciarRevisaoErros(null);
                    },
                  ),
                  const Divider(),
                ],
                ...materiasComErro.map((data) {
                  final materia = data['materia'] as Materia;
                  final questoesErradas = data['questoes_erradas'] as List<Questao>;
                  return ListTile(
                    leading: Icon(Icons.book, color: materia.cor ?? Colors.blue),
                    title: Text(materia.nome),
                    subtitle: Text('${questoesErradas.length} questões'),
                    onTap: () {
                      Navigator.pop(context);
                      _iniciarRevisaoErros(materia.id);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      }
    );
  }

  void _iniciarRevisaoErros(int? materiaId) {
    List<Questao> questoesErradas = [];
    String assunto = 'Revisão de Erros';

    if (materiaId == null) {
      for (var data in _statsPorMateria.values) {
        questoesErradas.addAll(data['questoes_erradas'] as List<Questao>);
      }
    } else {
      questoesErradas.addAll(_statsPorMateria[materiaId]!['questoes_erradas'] as List<Questao>);
      final materia = _statsPorMateria[materiaId]!['materia'] as Materia;
      assunto = 'Revisão: ${materia.nome}';
    }

    if (questoesErradas.isEmpty) return;

    // Clone list and shuffle options
    List<Questao> questoesParaRevisar = List.from(questoesErradas);
    questoesParaRevisar.shuffle();
    for (var questao in questoesParaRevisar) {
      String respostaCorreta = questao.opcoes[questao.indiceRespostaCorreta];
      questao.opcoes = List.from(questao.opcoes)..shuffle();
      questao.indiceRespostaCorreta = questao.opcoes.indexOf(respostaCorreta);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaQuiz(
          questoes: questoesParaRevisar,
          assunto: assunto,
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_statsPorMateria.isEmpty) return const SizedBox.shrink();

    List<BarChartGroupData> barGroups = [];
    int index = 0;
    
    _statsPorMateria.forEach((materiaId, data) {
      final acertos = (data['acertos'] as int).toDouble();
      final erros = (data['erros'] as int).toDouble();
      
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: acertos,
              color: const Color(0xFF10B981),
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: erros,
              color: const Color(0xFFEF4444),
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      index++;
    });

    return Container(
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Desempenho por Matéria',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _statsPorMateria.length) {
                          final key = _statsPorMateria.keys.elementAt(value.toInt());
                          final materia = _statsPorMateria[key]!['materia'] as Materia;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              materia.nome.length > 7 ? '${materia.nome.substring(0, 7)}...' : materia.nome,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(const Color(0xFF10B981), 'Acertos'),
              const SizedBox(width: 24),
              _buildLegend(const Color(0xFFEF4444), 'Erros'),
            ],
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    double max = 0;
    _statsPorMateria.forEach((_, data) {
      final acertos = (data['acertos'] as int).toDouble();
      final erros = (data['erros'] as int).toDouble();
      if (acertos > max) max = acertos;
      if (erros > max) max = erros;
    });
    return max == 0 ? 10 : max + (max * 0.2); // 20% margin
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool temErrosParaRevisar = _statsPorMateria.values.any((data) => (data['questoes_erradas'] as List<Questao>).isNotEmpty);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Estatísticas'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _statsPorMateria.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Nenhuma estatística disponível.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBarChart(),
                  const SizedBox(height: 24),
                  const Text(
                    'Detalhes por Matéria',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 16),
                  ..._statsPorMateria.values.map((data) {
                    final materia = data['materia'] as Materia;
                    final acertos = data['acertos'] as int;
                    final erros = data['erros'] as int;
                    final total = acertos + erros;
                    final taxaAcerto = total > 0 ? (acertos / total) * 100 : 0;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: (materia.cor ?? Colors.blue).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.book, color: materia.cor ?? Colors.blue),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    materia.nome,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$acertos Acertos | $erros Erros',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${taxaAcerto.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: taxaAcerto >= 60 ? Colors.green : Colors.red,
                                  ),
                                ),
                                Text(
                                  'Taxa de acerto',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 80), // Espaço para não ficar atrás do botão flutuante
                ],
              ),
            ),
      floatingActionButton: temErrosParaRevisar
          ? FloatingActionButton.extended(
              onPressed: _mostrarOpcoesRevisao,
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Revisar Erros',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
