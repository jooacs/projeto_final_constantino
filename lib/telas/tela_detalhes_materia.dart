import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../database/db_constants.dart';

import '../models/materia.dart';
import '../models/tarefa.dart';
import '../models/documento.dart';
import '../services/tarefa_service.dart';
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
  final GeminiService geminiService = GeminiService();
  final DocumentoService documentoService = DocumentoService();

  List<Tarefa> tarefas = [];
  bool _isLoadingTarefas = false;

  @override
  void initState() {
    super.initState();
    carregarTarefas();
  }

  // ================= IA & PDF =================

  Future<void> _anexarPdf(Tarefa tarefa) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        _mostrarSucesso('Gerando resumo via IA, por favor aguarde...');

        final summary = await geminiService.summarizePdf(
          result.files.single.bytes!,
        );

        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final savedFile = File(path.join(appDir.path, fileName));
        await savedFile.writeAsBytes(result.files.single.bytes!);

        final novoDoc = Documento(
          titulo: 'Resumo: ${tarefa.titulo}',
          tipo: 'resumo',
          caminho: savedFile.path,
          nomeArquivo: result.files.single.name,
          resumo: summary,
          dataCriacao: DateTime.now().toIso8601String(),
        );

        final docId = await documentoService.insertDocumento(novoDoc);
        tarefa.documentoId = docId;
        await tarefaService.atualizarTarefa(tarefa);
        await carregarTarefas();
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

  // ================= TAREFAS =================

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

  Future<void> adicionarTarefa(
    String titulo,
    String descricao,
    String prioridade,
    DateTime? dataCriacao,
    DateTime? dataEntrega,
  ) async {
    try {
      final tarefa = Tarefa(
        titulo: titulo,
        descricao: descricao,
        concluida: false,
        idMateria: widget.materia.id!,
        dataCriacao: dataCriacao ?? DateTime.now(),
        dataEntrega: dataEntrega,
        prioridade: prioridade,
      );
      await tarefaService.inserirTarefa(tarefa);
      if (!mounted) return;
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

  // ================= UTEIS =================

  Future<bool?> _confirmarExclusao(String titulo) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
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

  // ================= DIALOG =================

  void abrirDialogAdicionarTarefa() {
    final tituloCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();

    DateTime dataCriacao = DateTime.now();
    DateTime? dataEntrega;
    String prioridadeSelecionada = prioridadeMedia;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: const Color(0xFFF1ECF7),
              title: const Text(
                'Nova Tarefa',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: tituloCtrl,
                        decoration: InputDecoration(
                          hintText: 'Título',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: descricaoCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Descrição',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Prioridade',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 6),

                      DropdownButtonFormField<String>(
                        value: prioridadeSelecionada,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: prioridadeBaixa,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xFF10B981),
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text('Baixa'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: prioridadeMedia,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xFFF59E0B),
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text('Média'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: prioridadeAlta,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xFFEF4444),
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Text('Alta'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              prioridadeSelecionada = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 18),

                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final data = await showDatePicker(
                            context: ctx,
                            initialDate: dataCriacao,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (data != null) {
                            setDialogState(() {
                              dataCriacao = data;
                            });
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Data de Criação',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(dataCriacao),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: Color(0xFF4F46E5),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final data = await showDatePicker(
                            context: ctx,
                            initialDate: dataEntrega ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (data != null) {
                            setDialogState(() {
                              dataEntrega = data;
                            });
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Data de Entrega',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dataEntrega == null
                                        ? 'Sem prazo'
                                        : _formatDate(dataEntrega!),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.event_rounded,
                              color: Color(0xFF4F46E5),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Vinculada à matéria: ${widget.materia.nome}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Color(0xFF6D5D9A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    if (tituloCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Informe o título da tarefa.'),
                        ),
                      );
                      return;
                    }

                    try {
                      final tarefa = Tarefa(
                        titulo: tituloCtrl.text.trim(),
                        descricao: descricaoCtrl.text.trim(),
                        concluida: false,
                        idMateria: widget.materia.id!,
                        dataCriacao: dataCriacao,
                        dataEntrega: dataEntrega,
                        prioridade: prioridadeSelecionada,
                        idProva: null,
                      );

                      await tarefaService.inserirTarefa(tarefa);

                      if (!mounted) return;

                      Navigator.pop(ctx);

                      await carregarTarefas();

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tarefa adicionada!'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erro ao adicionar tarefa: $e')),
                      );
                    }
                  },
                  child: const Text(
                    'Salvar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
                  child: const Icon(Icons.menu_book, color: Colors.white),
                ),
                title: Text(
                  widget.materia.nome,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(widget.materia.professor),
              ),
            ),
          ),
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
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tarefa.documentoId != null)
                        IconButton(
                          icon: const Icon(
                            Icons.description,
                            color: Color(0xFF8B5CF6),
                          ),
                          onPressed: () => _verResumo(tarefa.documentoId!),
                          tooltip: 'Ver Resumo',
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () => _anexarPdf(tarefa),
                          tooltip: 'Anexar PDF (IA)',
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => deletarTarefa(index),
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
