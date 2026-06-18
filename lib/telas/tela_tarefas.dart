import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database/db_constants.dart';
import '../models/documento.dart';
import '../models/materia.dart';
import '../models/prova.dart';
import '../models/tarefa.dart';
import '../services/documento_service.dart';
import '../services/gemini_service.dart';
import '../services/materia_service.dart';
import '../services/prova_service.dart';
import '../services/tarefa_service.dart';

class TelaTarefas extends StatefulWidget {
  const TelaTarefas({super.key});

  @override
  State<TelaTarefas> createState() => _TelaTarefasState();
}

class _TelaTarefasState extends State<TelaTarefas>
    with SingleTickerProviderStateMixin {
  final TarefaService _tarefaService = TarefaService();
  final MateriaService _materiaService = MateriaService();
  final ProvaService _provaService = ProvaService();
  final DocumentoService _documentoService = DocumentoService();
  final GeminiService _geminiService = GeminiService();

  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  List<Tarefa> _tarefas = [];
  List<Tarefa> _tarefasPendentes = [];
  List<Tarefa> _tarefasConcluidas = [];

  List<Materia> _materias = [];
  List<Prova> _provasDaMateria = [];

  late TabController _tabController;

  bool _isLoading = true;

  DateTime? _dataCriacaoTarefa;
  DateTime? _dataEntregaTarefa;
  String _prioridadeTarefa = prioridadeMedia;

  Materia? _materiaSelecionada;
  Prova? _provaVinculada;
  PlatformFile? _pdfAnexoSelecionado;

  @override
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarDados();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);

    try {
      final tarefas = await _tarefaService.buscarTodas();
      final materias = await _materiaService.buscarMaterias();

      if (!mounted) return;

      final pendentes = tarefas.where((t) => !t.concluida).toList();
      final concluidas = tarefas.where((t) => t.concluida).toList();

      pendentes.sort((a, b) {
        if (a.dataEntrega == null && b.dataEntrega == null) return 0;
        if (a.dataEntrega == null) return 1;
        if (b.dataEntrega == null) return -1;
        return a.dataEntrega!.compareTo(b.dataEntrega!);
      });

      concluidas.sort((a, b) {
        if (a.dataConclusao == null && b.dataConclusao == null) return 0;
        if (a.dataConclusao == null) return 1;
        if (b.dataConclusao == null) return -1;
        return b.dataConclusao!.compareTo(a.dataConclusao!);
      });

      setState(() {
        _tarefas = tarefas;
        _tarefasPendentes = pendentes;
        _tarefasConcluidas = concluidas;
        _materias = materias;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar tarefas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _abrirPdf(int docId) async {
    try {
      final docs = await _documentoService.getDocumentos();
      final doc = docs.firstWhere((d) => d.id == docId);

      final arquivo = File(doc.caminho);

      if (!await arquivo.exists()) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arquivo PDF não encontrado no dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await OpenFilex.open(doc.caminho);

      if (result.type != ResultType.done) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível abrir o PDF: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _carregarProvasDaMateria(
    Materia? materia,
    void Function(void Function()) setDialogState,
  ) async {
    if (materia == null || materia.id == null) {
      setDialogState(() {
        _provasDaMateria = [];
        _provaVinculada = null;
      });
      return;
    }

    final provas = await _provaService.buscarPorMateria(materia.id!);

    setDialogState(() {
      _provasDaMateria = provas;
      _provaVinculada = null;
    });
  }

  Future<void> _processarAnexo(Tarefa tarefa, PlatformFile file) async {
    if (file.bytes == null) return;

    final resumo = await _geminiService.summarizePdf(file.bytes!);

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final savedFile = File(path.join(appDir.path, fileName));

    await savedFile.writeAsBytes(file.bytes!);

    final documento = Documento(
      titulo: 'Anexo: ${tarefa.titulo}',
      tipo: 'anexo',
      caminho: savedFile.path,
      nomeArquivo: file.name,
      resumo: resumo,
      dataCriacao: DateTime.now().toIso8601String(),
      idProva: tarefa.idProva,
    );

    final docId = await _documentoService.insertDocumento(documento);

    tarefa.documentoId = docId;
    await _tarefaService.atualizarTarefa(tarefa);
  }

  Future<void> _anexarPdf(Tarefa tarefa) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gerando resumo via IA, aguarde...'),
          backgroundColor: Color(0xFF4F46E5),
        ),
      );

      await _processarAnexo(tarefa, result.files.single);

      if (!mounted) return;

      await _carregarDados();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF anexado e resumido com sucesso!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao anexar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verResumo(int docId) async {
    try {
      final docs = await _documentoService.getDocumentos();
      final doc = docs.firstWhere((d) => d.id == docId);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(doc.titulo),
            content: SingleChildScrollView(
              child: MarkdownBody(
                data: doc.resumo ?? 'Sem resumo disponível.',
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 16, height: 1.5),
                  h1: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir resumo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _adicionarTarefa(BuildContext dialogContext) async {
    if (_tituloController.text.trim().isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Informe o título da tarefa.')),
      );
      return;
    }

    if (_materiaSelecionada == null || _materiaSelecionada!.id == null) {
      ScaffoldMessenger.of(
        dialogContext,
      ).showSnackBar(const SnackBar(content: Text('Selecione uma matéria.')));
      return;
    }

    final pdfSelecionado = _pdfAnexoSelecionado;

    Navigator.pop(dialogContext);

    try {
      final tarefa = Tarefa(
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        concluida: false,
        idMateria: _materiaSelecionada!.id!,
        dataCriacao: _dataCriacaoTarefa ?? DateTime.now(),
        dataEntrega: _dataEntregaTarefa,
        prioridade: _prioridadeTarefa,
        idProva: _provaVinculada?.id,
      );

      final id = await _tarefaService.inserirTarefa(tarefa);
      tarefa.id = id;

      if (pdfSelecionado != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salvando tarefa e lendo PDF, aguarde...'),
            backgroundColor: Color(0xFF4F46E5),
          ),
        );

        await _processarAnexo(tarefa, pdfSelecionado);
      }

      if (!mounted) return;

      await _carregarDados();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarefa adicionada com sucesso!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao adicionar tarefa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirDialogAdicionarTarefa() {
    if (_materias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre pelo menos uma matéria antes.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    _tituloController.clear();
    _descricaoController.clear();

    _dataCriacaoTarefa = DateTime.now();
    _dataEntregaTarefa = null;
    _prioridadeTarefa = prioridadeMedia;
    _materiaSelecionada = _materias.first;
    _provaVinculada = null;
    _pdfAnexoSelecionado = null;
    _provasDaMateria = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (_provasDaMateria.isEmpty && _materiaSelecionada != null) {
              Future.microtask(() {
                _carregarProvasDaMateria(_materiaSelecionada, setDialogState);
              });
            }

            return AlertDialog(
              title: const Text(
                'Nova Tarefa',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Matéria',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),

                      DropdownButtonFormField<Materia>(
                        value: _materiaSelecionada,
                        isExpanded: true,
                        items: _materias.map((m) {
                          return DropdownMenuItem<Materia>(
                            value: m,
                            child: Text(
                              m.nome,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (materia) async {
                          setDialogState(() {
                            _materiaSelecionada = materia;
                            _provaVinculada = null;
                            _provasDaMateria = [];
                          });

                          await _carregarProvasDaMateria(
                            materia,
                            setDialogState,
                          );
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: _tituloController,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: _descricaoController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Prioridade',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),

                      DropdownButtonFormField<String>(
                        value: _prioridadeTarefa,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: prioridadeBaixa,
                            child: Text('🟢  Baixa'),
                          ),
                          DropdownMenuItem(
                            value: prioridadeMedia,
                            child: Text('🟡  Média'),
                          ),
                          DropdownMenuItem(
                            value: prioridadeAlta,
                            child: Text('🔴  Alta'),
                          ),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            _prioridadeTarefa = v ?? prioridadeMedia;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Data de Criação'),
                        subtitle: Text(
                          _dataCriacaoTarefa != null
                              ? _formatDate(_dataCriacaoTarefa!)
                              : 'Selecionar',
                        ),
                        trailing: const Icon(Icons.calendar_today_rounded),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: _dataCriacaoTarefa ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              _dataCriacaoTarefa = picked;
                            });
                          }
                        },
                      ),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Data de Entrega'),
                        subtitle: Text(
                          _dataEntregaTarefa != null
                              ? _formatDate(_dataEntregaTarefa!)
                              : 'Sem prazo',
                        ),
                        trailing: const Icon(Icons.event_rounded),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: _dataEntregaTarefa ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              _dataEntregaTarefa = picked;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                            withData: true,
                          );

                          if (result != null &&
                              result.files.single.bytes != null) {
                            setDialogState(() {
                              _pdfAnexoSelecionado = result.files.single;
                            });
                          }
                        },
                        icon: Icon(
                          _pdfAnexoSelecionado != null
                              ? Icons.check_circle
                              : Icons.picture_as_pdf,
                          color: _pdfAnexoSelecionado != null
                              ? Colors.green
                              : null,
                        ),
                        label: Text(
                          _pdfAnexoSelecionado != null
                              ? 'PDF: ${_pdfAnexoSelecionado!.name}'
                              : 'Anexar PDF (opcional)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (_provasDaMateria.isNotEmpty) ...[
                        const Text(
                          'Vincular a uma prova (opcional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),

                        DropdownButtonFormField<Prova?>(
                          value: _provaVinculada,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<Prova?>(
                              value: null,
                              child: Text('Nenhuma'),
                            ),
                            ..._provasDaMateria.map((p) {
                              return DropdownMenuItem<Prova?>(
                                value: p,
                                child: Text(
                                  p.titulo,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (v) {
                            setDialogState(() {
                              _provaVinculada = v;
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => _adicionarTarefa(ctx),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _alternarStatusTarefa(Tarefa tarefa) async {
    try {
      tarefa.concluida = !tarefa.concluida;
      tarefa.dataConclusao = tarefa.concluida ? DateTime.now() : null;

      await _tarefaService.atualizarTarefa(tarefa);
      await _carregarDados();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tarefa.concluida ? 'Tarefa concluída!' : 'Tarefa pendente!',
          ),
          backgroundColor: tarefa.concluida
              ? const Color(0xFF10B981)
              : const Color(0xFF64748B),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar tarefa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletarTarefa(Tarefa tarefa) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remover tarefa?'),
          content: Text('Deseja remover "${tarefa.titulo}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) return;

    try {
      await _tarefaService.removerTarefa(tarefa.id!);
      await _carregarDados();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarefa removida!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover tarefa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _diasParaConcluirTexto(Tarefa tarefa) {
    if (tarefa.concluida) return 'Concluída';
    if (tarefa.dataEntrega == null) return 'Sem prazo definido';

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final entregaSemHora = DateTime(
      tarefa.dataEntrega!.year,
      tarefa.dataEntrega!.month,
      tarefa.dataEntrega!.day,
    );

    final diff = entregaSemHora.difference(hojeSemHora).inDays;

    if (diff < 0) return 'Atrasada há ${-diff} dia(s)';
    if (diff == 0) return 'Vence hoje';
    if (diff == 1) return 'Vence amanhã';
    return 'Faltam $diff dias';
  }

  Color _corDiasParaConcluir(Tarefa tarefa) {
    if (tarefa.concluida) return const Color(0xFF94A3B8);
    if (tarefa.dataEntrega == null) return const Color(0xFF64748B);

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final entregaSemHora = DateTime(
      tarefa.dataEntrega!.year,
      tarefa.dataEntrega!.month,
      tarefa.dataEntrega!.day,
    );

    final diff = entregaSemHora.difference(hojeSemHora).inDays;

    if (diff < 0) return const Color(0xFFEF4444);
    if (diff <= 1) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Color _corPrioridade(String prioridade) {
    switch (prioridade) {
      case prioridadeAlta:
        return const Color(0xFFEF4444);
      case prioridadeBaixa:
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _labelPrioridade(String prioridade) {
    switch (prioridade) {
      case prioridadeAlta:
        return 'Alta';
      case prioridadeBaixa:
        return 'Baixa';
      default:
        return 'Média';
    }
  }

  Widget _buildListaTarefas(
    List<Tarefa> tarefas, {
    required String mensagemVazia,
    required String subMensagem,
    required IconData icone,
    required Color corIcone,
  }) {
    if (tarefas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 80, color: corIcone),
            const SizedBox(height: 16),
            Text(
              mensagemVazia,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subMensagem,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFCBD5E1)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: tarefas.length,
        itemBuilder: (context, index) {
          final tarefa = tarefas[index];
          final materia = _buscarMateriaDaTarefa(tarefa);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: CheckboxListTile(
                value: tarefa.concluida,
                activeColor: const Color(0xFF10B981),
                onChanged: (_) => _alternarStatusTarefa(tarefa),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tarefa.documentoId != null) ...[
                      IconButton(
                        tooltip: 'Ver resumo',
                        icon: const Icon(
                          Icons.description_rounded,
                          color: Color(0xFF8B5CF6),
                        ),
                        onPressed: () => _verResumo(tarefa.documentoId!),
                      ),
                      IconButton(
                        tooltip: 'Abrir PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.red,
                        ),
                        onPressed: () => _abrirPdf(tarefa.documentoId!),
                      ),
                    ] else
                      IconButton(
                        tooltip: 'Anexar PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () => _anexarPdf(tarefa),
                      ),
                    IconButton(
                      tooltip: 'Remover tarefa',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      onPressed: () => _deletarTarefa(tarefa),
                    ),
                  ],
                ),
                title: Text(
                  tarefa.titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: tarefa.concluida
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tarefa.descricao.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(tarefa.descricao),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (materia != null)
                          _buildChip(
                            materia.nome,
                            const Color(0xFF4F46E5),
                            icone: Icons.menu_book_rounded,
                          ),
                        _buildChip(
                          _labelPrioridade(tarefa.prioridade),
                          _corPrioridade(tarefa.prioridade),
                          icone: Icons.flag_rounded,
                        ),
                        _buildChip(
                          _diasParaConcluirTexto(tarefa),
                          _corDiasParaConcluir(tarefa),
                          icone: Icons.event_rounded,
                        ),
                        if (tarefa.dataEntrega != null)
                          _buildChip(
                            'Entrega: ${_formatDate(tarefa.dataEntrega!)}',
                            const Color(0xFF64748B),
                          ),
                        if (tarefa.dataCriacao != null)
                          _buildChip(
                            'Criada: ${_formatDate(tarefa.dataCriacao!)}',
                            const Color(0xFF94A3B8),
                          ),
                        if (tarefa.concluida && tarefa.dataConclusao != null)
                          _buildChip(
                            'Concluída: ${_formatDate(tarefa.dataConclusao!)}',
                            const Color(0xFF10B981),
                          ),
                        if (tarefa.idProva != null)
                          _buildChip(
                            'Vinculada à prova',
                            const Color(0xFFEF4444),
                            icone: Icons.link_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip(String texto, Color cor, {IconData? icone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Materia? _buscarMateriaDaTarefa(Tarefa tarefa) {
    for (final materia in _materias) {
      if (materia.id == tarefa.idMateria) return materia;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      appBar: AppBar(
        title: const Text('Todas as Tarefas'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF10B981),
          tabs: [
            Tab(
              text: 'Pendentes (${_tarefasPendentes.length})',
              icon: const Icon(Icons.pending_actions_rounded, size: 18),
            ),
            Tab(
              text: 'Concluídas (${_tarefasConcluidas.length})',
              icon: const Icon(Icons.check_circle_rounded, size: 18),
            ),
          ],
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListaTarefas(
                  _tarefasPendentes,
                  mensagemVazia: 'Nenhuma tarefa pendente!',
                  subMensagem: 'Você está em dia com suas tarefas.',
                  icone: Icons.celebration_rounded,
                  corIcone: const Color(0xFF10B981),
                ),
                _buildListaTarefas(
                  _tarefasConcluidas,
                  mensagemVazia: 'Nenhuma tarefa concluída ainda.',
                  subMensagem:
                      'As tarefas marcadas como concluídas aparecerão aqui.',
                  icone: Icons.task_alt_rounded,
                  corIcone: const Color(0xFFE2E8F0),
                ),
              ],
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogAdicionarTarefa,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        tooltip: 'Nova Tarefa',
        child: const Icon(Icons.add_task_rounded),
      ),
    );
  }
}
