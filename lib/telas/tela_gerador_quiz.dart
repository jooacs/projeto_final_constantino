import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:fl_chart/fl_chart.dart';
import '../services/gemini_service.dart';
import '../models/questao.dart';
import '../models/documento.dart';
import '../models/materia.dart';
import '../models/tarefa.dart';
import '../services/documento_service.dart';
import '../services/materia_service.dart';
import '../services/tarefa_service.dart';
import 'tela_quiz.dart';

class TelaGeradorQuiz extends StatefulWidget {
  const TelaGeradorQuiz({super.key});

  @override
  State<TelaGeradorQuiz> createState() => _TelaGeradorQuizState();
}

class _TelaGeradorQuizState extends State<TelaGeradorQuiz> {
  final GeminiService _geminiService = GeminiService();
  final DocumentoService _documentoService = DocumentoService();
  final MateriaService _materiaService = MateriaService();
  final TarefaService _tarefaService = TarefaService();
  
  String? _pdfName;
  bool _isLoading = false;
  String? _errorMessage;
  String _loadingMessage = '';
  
  int _numQuestoes = 5;
  List<Documento> _historico = [];
  
  // Dados para os dropdowns
  List<Materia> _materias = [];
  List<Tarefa> _tarefas = [];
  
  // Seleções para criar
  Materia? _selectedMateriaCreate;
  Tarefa? _selectedTarefaCreate;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final materias = await _materiaService.buscarMaterias();
      final tarefas = await _tarefaService.buscarTodas();
      
      setState(() {
        _materias = materias;
        _tarefas = tarefas;
      });
      await _carregarHistorico();
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    }
  }

  Future<void> _carregarHistorico() async {
    final docs = await _documentoService.getDocumentos();
    setState(() {
      _historico = docs.where((d) => d.tipo == 'quiz').toList();
    });
  }

  Future<void> _pickAndGenerateQuiz() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pdfName = result.files.single.name;
          _isLoading = true;
          _errorMessage = null;
          _loadingMessage = 'A IA está lendo o PDF e\ngerando o seu Quiz...';
        });

        // Salvar arquivo localmente
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final savedFile = File(path.join(appDir.path, fileName));
        await savedFile.writeAsBytes(result.files.single.bytes!);

        final questoes = await _geminiService.generateQuizFromPdf(
          result.files.single.bytes!,
          numberOfQuestions: _numQuestoes,
        );
        
        final Map<String, dynamic> respostasData = {
          'id_materia': _selectedMateriaCreate?.id,
          'id_tarefa': _selectedTarefaCreate?.id,
          'acertos': 0,
          'erros': 0,
        };

        final novoDoc = Documento(
          titulo: _pdfName?.replaceAll('.pdf', '') ?? 'Assunto do PDF',
          tipo: 'quiz',
          caminho: savedFile.path,
          nomeArquivo: _pdfName!,
          questoes: jsonEncode(questoes.map((q) => q.toJson()).toList()),
          respostas: jsonEncode(respostasData),
          dataCriacao: DateTime.now().toIso8601String(),
        );
        novoDoc.id = await _documentoService.insertDocumento(novoDoc);
        await _carregarHistorico();

        setState(() {
          _isLoading = false;
        });

        if (!mounted) return;
        
        // Passa o documento para a tela de quiz para que os resultados possam ser salvos
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaQuiz(
              questoes: questoes,
              assunto: novoDoc.titulo,
              documento: novoDoc,
            ),
          ),
        );
        
        // Recarrega o histórico após voltar do quiz para atualizar o gráfico
        _carregarHistorico();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _abrirHistorico(Documento doc) async {
    if (doc.tipo == 'quiz' && doc.questoes != null) {
      final List<dynamic> jsonList = jsonDecode(doc.questoes!);
      List<Questao> questoes = jsonList.map((json) => Questao.fromJson(json)).toList();
      
      // Embaralha novamente ao abrir um quiz antigo
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
            assunto: doc.titulo,
            documento: doc,
          ),
        ),
      );
      
      _carregarHistorico(); // Atualiza as estatísticas ao voltar
    }
  }

  Future<void> _excluirHistorico(Documento doc) async {
    if (doc.id != null) {
      await _documentoService.deleteDocumento(doc.id!);
      
      try {
        final file = File(doc.caminho);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Erro ao deletar arquivo: $e');
      }

      await _carregarHistorico();
    }
  }

  Widget _buildEstatisticasGlobais() {
    final docs = _historico;
    int totalAcertos = 0;
    int totalErros = 0;

    for (var doc in docs) {
      if (doc.respostas != null) {
        try {
          final data = jsonDecode(doc.respostas!);
          totalAcertos += (data['acertos'] as int?) ?? 0;
          totalErros += (data['erros'] as int?) ?? 0;
        } catch (_) {}
      }
    }

    if (totalAcertos == 0 && totalErros == 0) {
      return const SizedBox.shrink(); // Não mostra o gráfico se não houver dados concluídos
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Estatísticas Gerais',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF334155),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: [
                  if (totalAcertos > 0)
                    PieChartSectionData(
                      color: const Color(0xFF10B981),
                      value: totalAcertos.toDouble(),
                      title: '$totalAcertos',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (totalErros > 0)
                    PieChartSectionData(
                      color: const Color(0xFFEF4444),
                      value: totalErros.toDouble(),
                      title: '$totalErros',
                      radius: 50,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Acertos', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(width: 20),
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Erros', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ],
              ),
            ],
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
        title: const Text('IA: Gerador de Quiz'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Área de Geração
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickAndGenerateQuiz,
                      icon: const Icon(Icons.quiz_rounded),
                      label: const Text(
                        'Criar Quiz a partir de PDF',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFFEC4899).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Materia>(
                            value: _selectedMateriaCreate,
                            decoration: InputDecoration(
                              labelText: 'Matéria (opcional)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<Materia>(value: null, child: Text('Nenhuma')),
                              ..._materias.map((m) => DropdownMenuItem(value: m, child: Text(m.nome))).toList(),
                            ],
                            onChanged: (val) => setState(() => _selectedMateriaCreate = val),
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<Tarefa>(
                            value: _selectedTarefaCreate,
                            decoration: InputDecoration(
                              labelText: 'Tarefa (opcional)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<Tarefa>(value: null, child: Text('Nenhuma')),
                              ..._tarefas.map((t) => DropdownMenuItem(value: t, child: Text(t.titulo))).toList(),
                            ],
                            onChanged: (val) => setState(() => _selectedTarefaCreate = val),
                            isExpanded: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Qtd. de Questões: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        DropdownButton<int>(
                          value: _numQuestoes,
                          items: const [
                            DropdownMenuItem(value: 5, child: Text('5')),
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 15, child: Text('15')),
                          ],
                          onChanged: _isLoading ? null : (val) {
                            if (val != null) setState(() => _numQuestoes = val);
                          },
                          underline: Container(),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFEC4899)),
                          style: const TextStyle(
                            color: Color(0xFFEC4899),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFEC4899),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Ops, ocorreu um erro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade600, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      return _buildHistoricoArea();
    }
  }

  Widget _buildHistoricoArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEstatisticasGlobais(),
        const Text(
          'Quizzes Salvos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _historico.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum quiz encontrado.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : ListView.builder(
                  itemCount: _historico.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final doc = _historico[index];
                    return Card(
                      elevation: 0,
                      color: const Color(0xFFF8FAFC),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEC4899).withOpacity(0.1),
                          child: const Icon(
                            Icons.quiz_rounded,
                            color: Color(0xFFEC4899),
                          ),
                        ),
                        title: Text(
                          doc.titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text(
                          'Quiz Salvo',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _excluirHistorico(doc),
                        ),
                        onTap: () => _abrirHistorico(doc),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
