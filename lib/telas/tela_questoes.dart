import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';

import '../models/tarefa.dart';
import '../models/prova.dart';
import '../models/materia.dart';
import '../models/documento.dart';
import '../models/questao.dart';

import '../services/tarefa_service.dart';
import '../services/prova_service.dart';
import '../services/materia_service.dart';
import '../services/documento_service.dart';
import '../services/gemini_service.dart';

import 'tela_quiz.dart';

class TelaQuestoes extends StatefulWidget {
  const TelaQuestoes({super.key});

  @override
  State<TelaQuestoes> createState() => _TelaQuestoesState();
}

class _TelaQuestoesState extends State<TelaQuestoes> {
  final TarefaService _tarefaService = TarefaService();
  final ProvaService _provaService = ProvaService();
  final MateriaService _materiaService = MateriaService();
  final DocumentoService _documentoService = DocumentoService();
  final GeminiService _geminiService = GeminiService();

  List<Map<String, dynamic>> _itensComPdf = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tarefas = await _tarefaService.buscarTodas();
      final provas = await _provaService.buscarTodas();
      final materias = await _materiaService.buscarMaterias();
      final documentos = await _documentoService.getDocumentos();

      final List<Map<String, dynamic>> resultados = [];

      for (var tarefa in tarefas) {
        if (tarefa.documentoId != null) {
          final doc = documentos.cast<Documento?>().firstWhere((d) => d?.id == tarefa.documentoId, orElse: () => null);
          if (doc != null) {
            final materia = materias.cast<Materia?>().firstWhere((m) => m?.id == tarefa.idMateria, orElse: () => null);
            resultados.add({
              'tipo': 'Tarefa',
              'item': tarefa,
              'documento': doc,
              'materia': materia,
            });
          }
        }
      }

      for (var prova in provas) {
        if (prova.documentoId != null) {
          final doc = documentos.cast<Documento?>().firstWhere((d) => d?.id == prova.documentoId, orElse: () => null);
          if (doc != null) {
            final materia = materias.cast<Materia?>().firstWhere((m) => m?.id == prova.idMateria, orElse: () => null);
            resultados.add({
              'tipo': 'Prova',
              'item': prova,
              'documento': doc,
              'materia': materia,
            });
          }
        }
      }

      setState(() {
        _itensComPdf = resultados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar dados: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _extrairOuResponderQuestoes(Map<String, dynamic> itemData) async {
    final Documento doc = itemData['documento'];
    final String nomeOrigem = itemData['tipo'] == 'Tarefa' ? (itemData['item'] as Tarefa).titulo : (itemData['item'] as Prova).titulo;

    if (doc.questoes != null && doc.questoes!.isNotEmpty) {
      // Já tem questões extraídas, abrir o quiz
      try {
        final List<dynamic> jsonList = jsonDecode(doc.questoes!);
        List<Questao> questoes = jsonList.map((json) => Questao.fromJson(json)).toList();

        // Embaralha novamente ao abrir
        questoes.shuffle();
        for (var questao in questoes) {
          String respostaCorreta = questao.opcoes[questao.indiceRespostaCorreta];
          questao.opcoes.shuffle();
          questao.indiceRespostaCorreta = questao.opcoes.indexOf(respostaCorreta);
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaQuiz(
              questoes: questoes,
              assunto: nomeOrigem,
              documento: doc,
            ),
          ),
        );
        _carregarDados(); // Recarrega para atualizar estatísticas, se necessário
      } catch (e) {
        _mostrarErro('Erro ao carregar questões salvas: $e');
      }
    } else {
      // Não tem questões, precisa extrair do PDF
      _mostrarLoading('Extraindo questões do PDF...');
      
      try {
        final file = File(doc.caminho);
        if (!await file.exists()) {
          Navigator.pop(context); // fecha loading
          _mostrarErro('Arquivo PDF não encontrado no dispositivo.');
          return;
        }

        final bytes = await file.readAsBytes();
        final questoes = await _geminiService.generateQuizFromPdf(bytes, numberOfQuestions: 5);

        // Salva as questões geradas no mesmo documento
        doc.questoes = jsonEncode(questoes.map((q) => q.toJson()).toList());
        await _documentoService.updateDocumento(doc);

        Navigator.pop(context); // fecha loading

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaQuiz(
              questoes: questoes,
              assunto: nomeOrigem,
              documento: doc,
            ),
          ),
        );
        _carregarDados(); // Atualiza a tela

      } catch (e) {
        Navigator.pop(context); // fecha loading
        _mostrarErro('Erro ao extrair questões: $e');
      }
    }
  }

  void _mostrarLoading(String mensagem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFFEC4899)),
              const SizedBox(width: 20),
              Expanded(child: Text(mensagem)),
            ],
          ),
        );
      },
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensagem),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Questões Extras'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _carregarDados, child: const Text('Tentar Novamente')),
                  ],
                ),
              ),
            )
          : _itensComPdf.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 80, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum PDF encontrado.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Anexe PDFs em suas Tarefas ou Provas para extrair questões.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _itensComPdf.length,
              itemBuilder: (context, index) {
                final itemData = _itensComPdf[index];
                final String tipo = itemData['tipo'];
                final dynamic item = itemData['item'];
                final Documento doc = itemData['documento'];
                final Materia? materia = itemData['materia'];
                
                final bool temQuestoes = doc.questoes != null && doc.questoes!.isNotEmpty;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (materia?.cor ?? Colors.blue).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                tipo == 'Tarefa' ? Icons.task_alt : Icons.assignment_late,
                                color: materia?.cor ?? Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tipo == 'Tarefa' ? (item as Tarefa).titulo : (item as Prova).titulo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    materia?.nome ?? 'Sem matéria',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tipo,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                doc.nomeArquivo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _extrairOuResponderQuestoes(itemData),
                            icon: Icon(temQuestoes ? Icons.play_arrow_rounded : Icons.auto_awesome),
                            label: Text(temQuestoes ? 'Responder Questões' : 'Extrair Questões (IA)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: temQuestoes ? const Color(0xFF10B981) : const Color(0xFFEC4899),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}