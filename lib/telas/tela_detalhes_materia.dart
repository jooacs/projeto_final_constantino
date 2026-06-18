import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../database/db_constants.dart';
import 'package:open_filex/open_filex.dart';
import '../models/materia.dart';
import '../models/tarefa.dart';
import '../models/prova.dart';
import '../models/documento.dart';
import '../services/tarefa_service.dart';
import '../services/prova_service.dart';
import '../services/gemini_service.dart';
import '../services/documento_service.dart';

class TelaDetalhesMateria extends StatefulWidget {
  final Materia materia;

  const TelaDetalhesMateria({super.key, required this.materia});

  @override
  State<TelaDetalhesMateria> createState() => _TelaDetalhesMateriaState();
}

class _TelaDetalhesMateriaState extends State<TelaDetalhesMateria> {
  final TarefaService tarefaService = TarefaService();
  final ProvaService provaService = ProvaService();
  final GeminiService geminiService = GeminiService();
  final DocumentoService documentoService = DocumentoService();

  // Controladores para Tarefa
  final tituloTarefaController = TextEditingController();
  final descricaoTarefaController = TextEditingController();
  DateTime? _dataCriacaoTarefa;
  DateTime? _dataEntregaTarefa;
  String _prioridadeTarefa = prioridadeMedia;
  Prova? _provaVinculadaTarefa; // vincula a tarefa criada a uma prova

  // Arquivo PDF opcional selecionado na criação
  List<PlatformFile> _pdfsAnexosSelecionados = [];

  List<Tarefa> tarefas = [];
  List<Prova> provas = [];
  bool _isLoadingTarefas = false;
  bool _isLoadingProvas = false;

  @override
  void initState() {
    super.initState();
    carregarTarefas();
  }

  // ================= IA & PDF =================

  Future<void> _processarAnexo(dynamic item, PlatformFile file) async {
    final summary = await geminiService.summarizePdf(file.bytes!);

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final savedFile = File(path.join(appDir.path, fileName));
    await savedFile.writeAsBytes(file.bytes!);

    final int? idProvaVinculada = item is Prova
        ? item.id
        : (item is Tarefa ? item.idProva : null);

    final novoDoc = Documento(
      titulo: 'Anexo: ${item.titulo}',
      tipo: 'anexo',
      caminho: savedFile.path,
      nomeArquivo: file.name,
      resumo: summary,
      dataCriacao: DateTime.now().toIso8601String(),
      idProva: idProvaVinculada,
    );

    final docId = await documentoService.insertDocumento(novoDoc);

    if (item is Tarefa) {
      item.documentoId = docId;
      await tarefaService.atualizarTarefa(item);
    } else if (item is Prova) {
      item.documentoId = docId;
      await provaService.atualizarProva(item);
    }
  }

  Future<void> _abrirPdf(int docId) async {
    try {
      final docs = await documentoService.getDocumentos();
      final doc = docs.firstWhere((d) => d.id == docId);

      final arquivo = File(doc.caminho);

      if (!await arquivo.exists()) {
        _mostrarErro('Arquivo PDF não encontrado no dispositivo.');
        return;
      }

      final result = await OpenFilex.open(doc.caminho);

      if (result.type != ResultType.done) {
        _mostrarErro('Não foi possível abrir o PDF: ${result.message}');
      }
    } catch (e) {
      _mostrarErro('Erro ao abrir PDF: $e');
    }
  }

  Future<void> _anexarPdf(dynamic item) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        _mostrarSucesso('Gerando resumo via IA, por favor aguarde...');
        await _processarAnexo(item, result.files.single);

        if (item is Tarefa) {
          await carregarTarefas();
        }

        _mostrarSucesso('PDF anexado e resumido com sucesso!');
      }
    } catch (e) {
      _mostrarErro('Erro ao gerar resumo: $e');
    }
  }

  Future<void> _salvarPdfNaTarefa(Tarefa tarefa, PlatformFile file) async {
    if (tarefa.id == null || file.bytes == null) return;

    final appDir = await getApplicationDocumentsDirectory();

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final savedFile = File(path.join(appDir.path, fileName));

    await savedFile.writeAsBytes(file.bytes!);

    final documento = Documento(
      titulo: file.name.replaceAll('.pdf', ''),
      tipo: 'pdf',
      caminho: savedFile.path,
      nomeArquivo: file.name,
      resumo: null,
      dataCriacao: DateTime.now().toIso8601String(),
      idTarefa: tarefa.id,
      idProva: tarefa.idProva,
    );

    final docId = await documentoService.insertDocumento(documento);

    // Mantém compatibilidade com telas antigas que usam documentoId
    tarefa.documentoId ??= docId;
  }

  Future<void> _anexarPdfsNaTarefa(Tarefa tarefa) async {
    if (tarefa.id == null) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        await _salvarPdfNaTarefa(tarefa, file);
      }

      await tarefaService.atualizarTarefa(tarefa);

      if (!mounted) return;

      await carregarTarefas();

      if (!mounted) return;

      _mostrarSucesso('PDF(s) anexado(s) com sucesso!');
    } catch (e) {
      if (!mounted) return;
      _mostrarErro('Erro ao anexar PDFs: $e');
    }
  }

  Future<void> _verPdfsDaTarefa(Tarefa tarefa) async {
    if (tarefa.id == null) return;

    try {
      final docs = await documentoService.buscarPorTarefa(tarefa.id!);

      if (!mounted) return;

      if (docs.isEmpty) {
        _mostrarErro('Essa tarefa ainda não possui PDFs.');
        return;
      }

      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final doc = docs[index];

                return ListTile(
                  leading: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.red,
                  ),
                  title: Text(
                    doc.nomeArquivo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(doc.titulo),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () async {
                    final arquivo = File(doc.caminho);

                    if (!await arquivo.exists()) {
                      if (!mounted) return;
                      _mostrarErro('Arquivo não encontrado no dispositivo.');
                      return;
                    }

                    await OpenFilex.open(doc.caminho);
                  },
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarErro('Erro ao abrir PDFs: $e');
    }
  }

  Future<void> _verResumo(int docId) async {
    try {
      final docs = await documentoService.getDocumentos();
      final doc = docs.firstWhere((d) => d.id == docId);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(doc.titulo),
          content: SingleChildScrollView(
            child: MarkdownBody(
              data: doc.resumo ?? 'Sem resumo disponível.',
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16, height: 1.5),
                h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarErro('Erro ao abrir documento: $e');
    }
  }

  @override
  void dispose() {
    tituloTarefaController.dispose();
    descricaoTarefaController.dispose();
    super.dispose();
  }

  Future<void> carregarTarefas() async {
    setState(() => _isLoadingTarefas = true);
    try {
      final lista = await tarefaService.buscarPorMateria(widget.materia.id!);
      if (mounted) {
        setState(() {
          tarefas = lista;
          _isLoadingTarefas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTarefas = false);
        _mostrarErro('Erro ao carregar tarefas: $e');
      }
    }
  }

  // ================= TAREFAS =================

  Future<void> adicionarTarefa() async {
    if (tituloTarefaController.text.trim().isEmpty) {
      _mostrarErro('Preencha o título da tarefa');
      return;
    }

    // Armazena o PDF selecionado localmente e fecha o dialog
    final pdfsSelecionados = List<PlatformFile>.from(_pdfsAnexosSelecionados);
    Navigator.pop(context);

    try {
      final tarefa = Tarefa(
        titulo: tituloTarefaController.text.trim(),
        descricao: descricaoTarefaController.text.trim(),
        concluida: false,
        idMateria: widget.materia.id!,
        dataCriacao: _dataCriacaoTarefa ?? DateTime.now(),
        dataEntrega: _dataEntregaTarefa,
        prioridade: _prioridadeTarefa,
        idProva: _provaVinculadaTarefa?.id,
      );

      final idTarefa = await tarefaService.inserirTarefa(tarefa);
      tarefa.id = idTarefa;

      if (pdfsSelecionados.isNotEmpty) {
        _mostrarSucesso('Salvando tarefa e PDF(s), aguarde...');

        for (final file in pdfsSelecionados) {
          await _salvarPdfNaTarefa(tarefa, file);
        }

        await tarefaService.atualizarTarefa(tarefa);

        _mostrarSucesso('Tarefa e PDF(s) adicionados com sucesso!');
      } else {
        _mostrarSucesso('Tarefa adicionada com sucesso!');
      }

      if (!mounted) return;
      tituloTarefaController.clear();
      descricaoTarefaController.clear();
      _dataCriacaoTarefa = null;
      _dataEntregaTarefa = null;
      _prioridadeTarefa = prioridadeMedia;
      _pdfsAnexosSelecionados = [];
      _provaVinculadaTarefa = null;
      await carregarTarefas();
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao adicionar tarefa: $e');
    }
  }

  Future<void> atualizarStatusTarefa(int index, bool? newValue) async {
    if (newValue == null) return;
    try {
      tarefas[index].concluida = newValue;
      tarefas[index].dataConclusao = newValue ? DateTime.now() : null;
      await tarefaService.atualizarTarefa(tarefas[index]);
      if (!mounted) return;
      await carregarTarefas();
      _mostrarSucesso(newValue ? 'Tarefa concluída!' : 'Tarefa pendente!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        tarefas[index].concluida = !newValue;
        tarefas[index].dataConclusao = !newValue ? DateTime.now() : null;
      });
      _mostrarErro('Erro ao atualizar tarefa: $e');
    }
  }

  Future<void> deletarTarefa(int index) async {
    final confirmado = await _confirmarExclusao(tarefas[index].titulo);
    if (confirmado == true) {
      try {
        await tarefaService.removerTarefa(tarefas[index].id!);
        if (mounted) {
          await carregarTarefas();
          _mostrarSucesso('Tarefa removida!');
        }
      } catch (e) {
        if (mounted) _mostrarErro('Erro ao remover tarefa: $e');
      }
    }
  }

  // ================= PROVAS =================

  /// Marca a prova como realizada/pendente.
  /// Ao marcar como realizada, pede a nota obtida e a registra também
  /// na tabela de Notas para entrar nos cálculos de desempenho.

  // ================= UTEIS =================

  Future<bool?> _confirmarExclusao(String titulo) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: Text('Tem certeza que deseja deletar "$titulo"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Deletar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
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
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.green),
    );
  }

  // ================= DIALOGS =================

  void abrirDialogAdicionarTarefa() {
    tituloTarefaController.clear();
    descricaoTarefaController.clear();
    _dataCriacaoTarefa = DateTime.now();
    _dataEntregaTarefa = null;
    _pdfsAnexosSelecionados = [];
    _provaVinculadaTarefa = null;
    _prioridadeTarefa = prioridadeMedia;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nova Tarefa'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: tituloTarefaController,
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descricaoTarefaController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Descrição'),
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
                      initialValue: _prioridadeTarefa,
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
                      onChanged: (v) => setDialogState(
                        () => _prioridadeTarefa = v ?? prioridadeMedia,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data de Criação'),
                      subtitle: Text(
                        _dataCriacaoTarefa != null
                            ? _formatDate(_dataCriacaoTarefa!)
                            : 'Selecionar',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dataCriacaoTarefa ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => _dataCriacaoTarefa = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data de Entrega'),
                      subtitle: Text(
                        _dataEntregaTarefa != null
                            ? _formatDate(_dataEntregaTarefa!)
                            : 'Sem prazo',
                      ),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dataEntregaTarefa ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => _dataEntregaTarefa = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          allowMultiple: true,
                          withData: true,
                        );

                        if (result != null && result.files.isNotEmpty) {
                          setDialogState(() {
                            _pdfsAnexosSelecionados = result.files
                                .where((file) => file.bytes != null)
                                .toList();
                          });
                        }
                      },
                      icon: Icon(
                        _pdfsAnexosSelecionados.isNotEmpty
                            ? Icons.check_circle
                            : Icons.picture_as_pdf,
                        color: _pdfsAnexosSelecionados.isNotEmpty
                            ? Colors.green
                            : null,
                      ),
                      label: Text(
                        _pdfsAnexosSelecionados.isNotEmpty
                            ? '${_pdfsAnexosSelecionados.length} PDF(s) selecionado(s)'
                            : 'Anexar PDF(s) opcional',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        side: BorderSide(
                          color: _pdfsAnexosSelecionados.isNotEmpty
                              ? Colors.green
                              : Colors.grey,
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (provas.isNotEmpty) ...[
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
                        initialValue: _provaVinculadaTarefa,
                        items: [
                          const DropdownMenuItem<Prova?>(
                            value: null,
                            child: Text('Nenhuma'),
                          ),
                          ...provas.map(
                            (p) => DropdownMenuItem<Prova?>(
                              value: p,
                              child: Text(
                                p.titulo,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => _provaVinculadaTarefa = v),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: adicionarTarefa,
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      appBar: AppBar(
        title: Text(widget.materia.nome),
        backgroundColor: Colors.transparent,
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: widget.materia.cor,
                  child: Icon(
                    widget.materia.icone ?? Icons.menu_book,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  widget.materia.nome,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(widget.materia.professor),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.task_alt_rounded, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(
                  'Tarefas da matéria',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(child: _buildListaTarefas()),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: abrirDialogAdicionarTarefa,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_task_rounded),
      ),
    );
  }

  Widget _buildListaTarefas() {
    if (_isLoadingTarefas) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tarefas.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma tarefa cadastrada. Clique no +',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tarefas.length,
      itemBuilder: (context, index) {
        final tarefa = tarefas[index];
        final provaVinculada = tarefa.idProva != null
            ? provas.where((p) => p.id == tarefa.idProva).firstOrNull
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tarefa.titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: tarefa.concluida
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: tarefa.descricao.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(tarefa.descricao),
                        )
                      : null,
                  value: tarefa.concluida,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) => atualizarStatusTarefa(index, val),
                  secondary: PopupMenuButton<String>(
                    tooltip: 'Opções',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) {
                      if (value == 'pdfs') {
                        _verPdfsDaTarefa(tarefa);
                      } else if (value == 'add_pdf') {
                        _anexarPdfsNaTarefa(tarefa);
                      } else if (value == 'delete') {
                        deletarTarefa(index);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'pdfs', child: Text('Ver PDFs')),
                      PopupMenuItem(
                        value: 'add_pdf',
                        child: Text('Adicionar PDF'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Remover tarefa'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
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
                      if (tarefa.concluida && tarefa.dataConclusao != null)
                        _buildChip(
                          'Concluída em: ${_formatDate(tarefa.dataConclusao!)}',
                          const Color(0xFF94A3B8),
                        ),
                      if (provaVinculada != null)
                        _buildChip(
                          '📝 ${provaVinculada.titulo}',
                          const Color(0xFFEF4444),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
