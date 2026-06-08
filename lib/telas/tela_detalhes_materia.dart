import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_markdown/flutter_markdown.dart';

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

class _TelaDetalhesMateriaState extends State<TelaDetalhesMateria> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TarefaService tarefaService = TarefaService();
  final ProvaService provaService = ProvaService();
  final GeminiService geminiService = GeminiService();
  final DocumentoService documentoService = DocumentoService();

  // Controladores para Tarefa
  final tituloTarefaController = TextEditingController();
  final descricaoTarefaController = TextEditingController();
  DateTime? _dataCriacaoTarefa;
  DateTime? _dataEntregaTarefa;

  // Controladores para Prova
  final tituloProvaController = TextEditingController();
  final descricaoProvaController = TextEditingController();
  final notaProvaController = TextEditingController();
  DateTime? _dataCriacaoProva;
  DateTime? _dataProva;

  List<Tarefa> tarefas = [];
  List<Prova> provas = [];
  bool _isLoadingTarefas = false;
  bool _isLoadingProvas = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Atualizar o ícone/ação do FAB quando mudar de aba
    });
    carregarTarefas();
    carregarProvas();
  }

  // ================= IA & PDF =================
  Future<void> _anexarPdf(dynamic item) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        _mostrarSucesso('Gerando resumo via IA, por favor aguarde...');
        
        final summary = await geminiService.summarizePdf(result.files.single.bytes!);
        
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final savedFile = File(path.join(appDir.path, fileName));
        await savedFile.writeAsBytes(result.files.single.bytes!);

        final novoDoc = Documento(
          titulo: 'Resumo: ${item.titulo}',
          tipo: 'resumo',
          caminho: savedFile.path,
          nomeArquivo: result.files.single.name,
          resumo: summary,
          dataCriacao: DateTime.now().toIso8601String(),
        );

        final docId = await documentoService.insertDocumento(novoDoc);

        if (item is Tarefa) {
          item.documentoId = docId;
          await tarefaService.atualizarTarefa(item);
          await carregarTarefas();
        } else if (item is Prova) {
          item.documentoId = docId;
          await provaService.atualizarProva(item);
          await carregarProvas();
        }
        
        _mostrarSucesso('Resumo gerado e anexado com sucesso!');
      }
    } catch (e) {
      _mostrarErro('Erro ao gerar resumo: $e');
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
    _tabController.dispose();
    tituloTarefaController.dispose();
    descricaoTarefaController.dispose();
    tituloProvaController.dispose();
    descricaoProvaController.dispose();
    notaProvaController.dispose();
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

  Future<void> carregarProvas() async {
    setState(() => _isLoadingProvas = true);
    try {
      final lista = await provaService.buscarPorMateria(widget.materia.id!);
      if (mounted) {
        setState(() {
          provas = lista;
          _isLoadingProvas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProvas = false);
        _mostrarErro('Erro ao carregar provas: $e');
      }
    }
  }

  // ================= TAREFAS =================

  Future<void> adicionarTarefa() async {
    if (tituloTarefaController.text.trim().isEmpty) {
      _mostrarErro('Preencha o título da tarefa');
      return;
    }
    try {
      final tarefa = Tarefa(
        titulo: tituloTarefaController.text.trim(),
        descricao: descricaoTarefaController.text.trim(),
        concluida: false,
        idMateria: widget.materia.id!,
        dataCriacao: _dataCriacaoTarefa ?? DateTime.now(),
        dataEntrega: _dataEntregaTarefa,
      );
      await tarefaService.inserirTarefa(tarefa);
      if (!mounted) return;
      tituloTarefaController.clear();
      descricaoTarefaController.clear();
      _dataCriacaoTarefa = null;
      _dataEntregaTarefa = null;
      await carregarTarefas();
      Navigator.pop(context);
      _mostrarSucesso('Tarefa adicionada com sucesso!');
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

  Future<void> adicionarProva() async {
    if (tituloProvaController.text.trim().isEmpty) {
      _mostrarErro('Preencha o título da prova');
      return;
    }
    try {
      final prova = Prova(
        titulo: tituloProvaController.text.trim(),
        descricao: descricaoProvaController.text.trim(),
        realizada: false,
        idMateria: widget.materia.id!,
        dataCriacao: _dataCriacaoProva ?? DateTime.now(),
        dataProva: _dataProva,
        nota: double.tryParse(notaProvaController.text),
      );
      await provaService.inserirProva(prova);
      if (!mounted) return;
      tituloProvaController.clear();
      descricaoProvaController.clear();
      notaProvaController.clear();
      _dataCriacaoProva = null;
      _dataProva = null;
      await carregarProvas();
      Navigator.pop(context);
      _mostrarSucesso('Prova adicionada com sucesso!');
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao adicionar prova: $e');
    }
  }

  Future<void> atualizarStatusProva(int index, bool? newValue) async {
    if (newValue == null) return;
    try {
      provas[index].realizada = newValue;
      await provaService.atualizarProva(provas[index]);
      if (!mounted) return;
      await carregarProvas();
      _mostrarSucesso(newValue ? 'Prova realizada!' : 'Prova pendente!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        provas[index].realizada = !newValue;
      });
      _mostrarErro('Erro ao atualizar prova: $e');
    }
  }

  Future<void> deletarProva(int index) async {
    final confirmado = await _confirmarExclusao(provas[index].titulo);
    if (confirmado == true) {
      try {
        await provaService.removerProva(provas[index].id!);
        if (mounted) {
          await carregarProvas();
          _mostrarSucesso('Prova removida!');
        }
      } catch (e) {
        if (mounted) _mostrarErro('Erro ao remover prova: $e');
      }
    }
  }

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
              child: const Text('Deletar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.red));
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: Colors.green));
  }

  // ================= DIALOGS =================

  void abrirDialogAdicionarTarefa() {
    tituloTarefaController.clear();
    descricaoTarefaController.clear();
    _dataCriacaoTarefa = DateTime.now();
    _dataEntregaTarefa = null;

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
                  children: [
                    TextField(controller: tituloTarefaController, decoration: const InputDecoration(labelText: 'Título')),
                    const SizedBox(height: 10),
                    TextField(controller: descricaoTarefaController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição')),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data de Criação'),
                      subtitle: Text(_dataCriacaoTarefa != null ? _formatDate(_dataCriacaoTarefa!) : 'Selecionar'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _dataCriacaoTarefa ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setDialogState(() => _dataCriacaoTarefa = picked);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data de Entrega'),
                      subtitle: Text(_dataEntregaTarefa != null ? _formatDate(_dataEntregaTarefa!) : 'Sem prazo'),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _dataEntregaTarefa ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setDialogState(() => _dataEntregaTarefa = picked);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(onPressed: adicionarTarefa, child: const Text('Salvar')),
              ],
            );
          }
        );
      },
    );
  }

  void abrirDialogAdicionarProva() {
    tituloProvaController.clear();
    descricaoProvaController.clear();
    notaProvaController.clear();
    _dataCriacaoProva = DateTime.now();
    _dataProva = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nova Prova'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: tituloProvaController, decoration: const InputDecoration(labelText: 'Título')),
                    const SizedBox(height: 10),
                    TextField(controller: descricaoProvaController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição (opcional)')),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Data da Prova'),
                      subtitle: Text(_dataProva != null ? _formatDate(_dataProva!) : 'Sem data definida'),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _dataProva ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setDialogState(() => _dataProva = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notaProvaController, 
                      keyboardType: TextInputType.number, 
                      decoration: const InputDecoration(labelText: 'Nota (Opcional)')
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(onPressed: adicionarProva, child: const Text('Salvar')),
              ],
            );
          }
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4F46E5),
          tabs: const [
            Tab(text: 'Tarefas', icon: Icon(Icons.task_alt_rounded)),
            Tab(text: 'Provas', icon: Icon(Icons.assignment_late_rounded)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: widget.materia.cor,
                  child: const Icon(Icons.menu_book, color: Colors.white),
                ),
                title: Text(widget.materia.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.materia.professor),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Aba Tarefas
                _buildListaTarefas(),
                // Aba Provas
                _buildListaProvas(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            abrirDialogAdicionarTarefa();
          } else {
            abrirDialogAdicionarProva();
          }
        },
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        child: Icon(_tabController.index == 0 ? Icons.add_task_rounded : Icons.post_add_rounded),
      ),
    );
  }

  Widget _buildListaTarefas() {
    if (_isLoadingTarefas) return const Center(child: CircularProgressIndicator());
    if (tarefas.isEmpty) {
      return const Center(child: Text('Nenhuma tarefa cadastrada. Clique no +', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tarefas.length,
      itemBuilder: (context, index) {
        final tarefa = tarefas[index];
        String datasTexto = '';
        if (tarefa.dataCriacao != null) datasTexto += 'Criado em: ${_formatDate(tarefa.dataCriacao!)}';
        if (tarefa.dataEntrega != null) datasTexto += '\nEntrega: ${_formatDate(tarefa.dataEntrega!)}';
        if (tarefa.concluida && tarefa.dataConclusao != null) datasTexto += '\nConcluído em: ${_formatDate(tarefa.dataConclusao!)}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: CheckboxListTile(
            title: Text(tarefa.titulo, style: TextStyle(fontWeight: FontWeight.bold, decoration: tarefa.concluida ? TextDecoration.lineThrough : null)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tarefa.descricao.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text(tarefa.descricao)),
                if (datasTexto.isNotEmpty) Text(datasTexto, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
              ],
            ),
            value: tarefa.concluida,
            activeColor: const Color(0xFF4F46E5),
            onChanged: (val) => atualizarStatusTarefa(index, val),
            secondary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tarefa.documentoId != null)
                  IconButton(
                    icon: const Icon(Icons.description, color: Color(0xFF8B5CF6)),
                    onPressed: () => _verResumo(tarefa.documentoId!),
                    tooltip: 'Ver Resumo',
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF64748B)),
                    onPressed: () => _anexarPdf(tarefa),
                    tooltip: 'Anexar PDF (IA)',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red), 
                  onPressed: () => deletarTarefa(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListaProvas() {
    if (_isLoadingProvas) return const Center(child: CircularProgressIndicator());
    if (provas.isEmpty) {
      return const Center(child: Text('Nenhuma prova cadastrada. Clique no +', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provas.length,
      itemBuilder: (context, index) {
        final prova = provas[index];
        String datasTexto = '';
        if (prova.dataProva != null) datasTexto += 'Data da Prova: ${_formatDate(prova.dataProva!)}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: CheckboxListTile(
            title: Text(prova.titulo, style: TextStyle(fontWeight: FontWeight.bold, decoration: prova.realizada ? TextDecoration.lineThrough : null)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prova.descricao.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text(prova.descricao)),
                if (datasTexto.isNotEmpty) Text(datasTexto, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                if (prova.nota != null) Text('Nota: ${prova.nota}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
              ],
            ),
            value: prova.realizada,
            activeColor: const Color(0xFF4F46E5),
            onChanged: (val) => atualizarStatusProva(index, val),
            secondary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (prova.documentoId != null)
                  IconButton(
                    icon: const Icon(Icons.description, color: Color(0xFF8B5CF6)),
                    onPressed: () => _verResumo(prova.documentoId!),
                    tooltip: 'Ver Resumo',
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF64748B)),
                    onPressed: () => _anexarPdf(prova),
                    tooltip: 'Anexar PDF (IA)',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red), 
                  onPressed: () => deletarProva(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
