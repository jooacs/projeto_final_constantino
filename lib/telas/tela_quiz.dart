import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/questao.dart';
import '../models/documento.dart';
import '../services/documento_service.dart';

class TelaQuiz extends StatefulWidget {
  final List<Questao> questoes;
  final String assunto;
  final Documento? documento;

  const TelaQuiz({super.key, required this.questoes, required this.assunto, this.documento});

  @override
  State<TelaQuiz> createState() => _TelaQuizState();
}

class _TelaQuizState extends State<TelaQuiz> {
  int _indiceQuestaoAtual = 0;
  late List<int?> _respostasSelecionadas;
  bool _quizFinalizado = false;

  @override
  void initState() {
    super.initState();
    _respostasSelecionadas = List.filled(widget.questoes.length, null);
  }

  void _proximaQuestao() {
    if (_respostasSelecionadas[_indiceQuestaoAtual] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma opção antes de continuar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_indiceQuestaoAtual < widget.questoes.length - 1) {
      setState(() {
        _indiceQuestaoAtual++;
      });
    } else {
      _finalizarQuiz();
    }
  }

  Future<void> _finalizarQuiz() async {
    setState(() {
      _quizFinalizado = true;
    });

    if (widget.documento != null) {
      int acertos = 0;
      int erros = 0;
      List<int> indicesErros = [];
      
      for (int i = 0; i < widget.questoes.length; i++) {
        if (_respostasSelecionadas[i] == widget.questoes[i].indiceRespostaCorreta) {
          acertos++;
        } else {
          erros++;
          indicesErros.add(i);
        }
      }

      Map<String, dynamic> respostasData = {};
      if (widget.documento!.respostas != null) {
        try {
          respostasData = jsonDecode(widget.documento!.respostas!);
        } catch (_) {}
      }

      respostasData['acertos'] = acertos;
      respostasData['erros'] = erros;
      respostasData['indicesErros'] = indicesErros;

      widget.documento!.respostas = jsonEncode(respostasData);
      
      final docService = DocumentoService();
      await docService.updateDocumento(widget.documento!);
    }
  }

  void _reiniciarQuiz() {
    setState(() {
      _indiceQuestaoAtual = 0;
      _respostasSelecionadas = List.filled(widget.questoes.length, null);
      _quizFinalizado = false;
    });
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        )
      ],
    );
  }

  Widget _buildTelaResultado() {
    int acertos = 0;
    int erros = 0;
    for (int i = 0; i < widget.questoes.length; i++) {
      if (_respostasSelecionadas[i] == widget.questoes[i].indiceRespostaCorreta) {
        acertos++;
      } else {
        erros++;
      }
    }

    double nota = (acertos / widget.questoes.length) * 10;
    bool aprovado = nota >= 6;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            aprovado ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
            size: 80,
            color: aprovado ? Colors.amber : Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'Resultado do Quiz: ${widget.assunto}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: aprovado ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: aprovado ? Colors.green.shade200 : Colors.red.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Nota: ${nota.toStringAsFixed(1)} / 10.0',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: aprovado ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Acertos: $acertos de ${widget.questoes.length}',
                  style: TextStyle(
                    fontSize: 16,
                    color: aprovado ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Gráfico Estatístico
          Container(
            padding: const EdgeInsets.all(20),
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
                  'Estatísticas de Desempenho',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        if (acertos > 0)
                          PieChartSectionData(
                            color: const Color(0xFF10B981), // Green
                            value: acertos.toDouble(),
                            title: '$acertos\n(${(acertos / widget.questoes.length * 100).toStringAsFixed(0)}%)',
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (erros > 0)
                          PieChartSectionData(
                            color: const Color(0xFFEF4444), // Red
                            value: erros.toDouble(),
                            title: '$erros\n(${(erros / widget.questoes.length * 100).toStringAsFixed(0)}%)',
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
          ),
          
          const SizedBox(height: 32),
          const Text(
            'Gabarito:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(widget.questoes.length, (index) {
            final questao = widget.questoes[index];
            final respostaUsuario = _respostasSelecionadas[index];
            final acertou = respostaUsuario == questao.indiceRespostaCorreta;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: acertou ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              color: acertou ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${questao.pergunta}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sua resposta: ${respostaUsuario != null ? questao.opcoes[respostaUsuario] : 'Nenhuma'}',
                      style: TextStyle(
                        color: acertou ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!acertou) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Resposta correta: ${questao.opcoes[questao.indiceRespostaCorreta]}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF8B5CF6).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Voltar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _reiniciarQuiz,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.all(16),
              foregroundColor: const Color(0xFF8B5CF6),
            ),
            child: const Text(
              'Tentar Novamente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuestao() {
    if (widget.questoes.isEmpty) {
      return const Center(child: Text('Nenhuma questão encontrada.'));
    }

    final questaoAtual = widget.questoes[_indiceQuestaoAtual];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_indiceQuestaoAtual + 1) / widget.questoes.length,
            backgroundColor: const Color(0xFFE2E8F0),
            color: const Color(0xFF8B5CF6),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 24),
          Text(
            'Questão ${_indiceQuestaoAtual + 1} de ${widget.questoes.length}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            questaoAtual.pergunta,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: questaoAtual.opcoes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final opcao = questaoAtual.opcoes[index];
                final selecionado = _respostasSelecionadas[_indiceQuestaoAtual] == index;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _respostasSelecionadas[_indiceQuestaoAtual] = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selecionado ? const Color(0xFF8B5CF6).withOpacity(0.1) : Colors.white,
                      border: Border.all(
                        color: selecionado ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
                        width: selecionado ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: index,
                          groupValue: _respostasSelecionadas[_indiceQuestaoAtual],
                          onChanged: (int? value) {
                            setState(() {
                              _respostasSelecionadas[_indiceQuestaoAtual] = value;
                            });
                          },
                          activeColor: const Color(0xFF8B5CF6),
                        ),
                        Expanded(
                          child: Text(
                            opcao,
                            style: TextStyle(
                              fontSize: 15,
                              color: selecionado ? const Color(0xFF8B5CF6) : const Color(0xFF334155),
                              fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _proximaQuestao,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(18),
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF8B5CF6).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _indiceQuestaoAtual == widget.questoes.length - 1 ? 'Finalizar Quiz' : 'Próxima Questão',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Quiz: ${widget.assunto}',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _quizFinalizado ? _buildTelaResultado() : _buildQuestao(),
      ),
    );
  }
}