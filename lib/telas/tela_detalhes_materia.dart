import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../database/db_constants.dart';

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
  String _prioridadeTarefa = prioridadeMedia;
<<<<<<< HEAD
=======
  Prova? _provaVinculadaTarefa; // NOVO: vincula a tarefa criada a uma prova
>>>>>>> d0eecb2bc4e35bdc331f6b3043eb41990fc1b8ae

  // Controladores para Prova
  final tituloProvaController = TextEditingController();
  final descricaoProvaController = TextEditingController();
  final notaProvaController = TextEditingController();
  final pesoProvaController = TextEditingController(text: '1.0'); // NOVO
  DateTime? _dataCriacaoProva;
  DateTime? _dataProva;

  // Arquivo PDF opcional selecionado na criação
  PlatformFile? _pdfAnexoSelecionado;

  List<Tarefa> tarefas = [];
  List<Prova> provas = [];
  bool _isLoadingTarefas = false;
  bool _isLoadingProvas = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    carregarTarefas();
    carregarProvas();
  }

  // ================= IA & PDF =================
  
  Future<void> _processarAnexo(dynamic item, PlatformFile file) async {
    final summary = await geminiService.summarizePdf(file.bytes!);
    
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final savedFile = File(path.join(appDir.path, fileName));
    await savedFile.writeAsBytes(file.bytes!);

    final novoDoc = Documento(
      titulo: 'Anexo: ${item.titulo}',
      tipo: 'anexo',
      caminho: savedFile.path,
      nomeArquivo: file.name,
      resumo: summary,
      dataCriacao: DateTime.now().toIso8601String(),
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

  Future<void> _anexarPdf(dynamic item) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        _mostrarSucesso('Gerando resumo via IA, por favor aguarde...');
        
<<<<<<< HEAD
        await _processarAnexo(item, result.files.single);
=======
        final summary = await geminiService.summarizePdf(result.files.single.bytes!);
        
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final savedFile = File(path.join(appDir.path, fileName));
        await savedFile.writeAsBytes(result.files.single.bytes!);

        // Se o item for uma Prova, vincula o resumo a ela (id_prova)
        final int? idProvaVinculada = item is Prova ? item.id : null;

        final novoDoc = Documento(
          titulo: 'Resumo: ${item.titulo}',
          tipo: 'resumo',
          caminho: savedFile.path,
          nomeArquivo: result.files.single.name,
          resumo: summary,
          dataCriacao: DateTime.now().toIso8601String(),
          idProva: idProvaVinculada,
        );

        final docId = await documentoService.insertDocumento(novoDoc);
>>>>>>> d0eecb2bc4e35bdc331f6b3043eb41990fc1b8ae

        if (item is Tarefa) {
          await carregarTarefas();
        } else if (item is Prova) {
          await carregarProvas();
        }
        
        _mostrarSucesso('PDF anexado e resumido com sucesso!');
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
    pesoProvaController.dispose();
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
    
    // Armazena o PDF selecionado localmente e fecha o dialog
    final pdfSelecionado = _pdfAnexoSelecionado;
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

      if (pdfSelecionado != null) {
        _mostrarSucesso('Salvando tarefa e lendo PDF, aguarde...');
        await _processarAnexo(tarefa, pdfSelecionado);
        _mostrarSucesso('Tarefa e anexo adicionados com sucesso!');
      } else {
        _mostrarSucesso('Tarefa adicionada com sucesso!');
      }

      if (!mounted) return;
      tituloTarefaController.clear();
      descricaoTarefaController.clear();
      _dataCriacaoTarefa = null;
      _dataEntregaTarefa = null;
      _prioridadeTarefa = prioridadeMedia;
<<<<<<< HEAD
      _pdfAnexoSelecionado = null;
=======
      _provaVinculadaTarefa = null;
>>>>>>> d0eecb2bc4e35bdc331f6b3043eb41990fc1b8ae
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

  Future<void> adicionarProva() async {
    if (tituloProvaController.text.trim().isEmpty) {
      _mostrarErro('Preencha o título da prova');
      return;
    }
<<<<<<< HEAD

    // Armazena o PDF selecionado localmente e fecha o dialog
    final pdfSelecionado = _pdfAnexoSelecionado;
    Navigator.pop(context);

=======
    final peso = double.tryParse(
            pesoProvaController.text.trim().replaceAll(',', '.')) ??
        1.0;
    if (peso <= 0) {
      _mostrarErro('O peso deve ser maior que zero');
      return;
    }
>>>>>>> d0eecb2bc4e35bdc331f6b3043eb41990fc1b8ae
    try {
      final prova = Prova(
        titulo: tituloProvaController.text.trim(),
        descricao: descricaoProvaController.text.trim(),
        realizada: false,
        idMateria: widget.materia.id!,
        dataCriacao: _dataCriacaoProva ?? DateTime.now(),
        dataProva: _dataProva,
        nota: double.tryParse(notaProvaController.text),
        peso: peso,
      );
      
      final idProva = await provaService.inserirProva(prova);
      prova.id = idProva;

      if (pdfSelecionado != null) {
        _mostrarSucesso('Salvando prova e lendo PDF, aguarde...');
        await _processarAnexo(prova, pdfSelecionado);
        _mostrarSucesso('Prova e anexo adicionados com sucesso!');
      } else {
        _mostrarSucesso('Prova adicionada com sucesso!');
      }

      if (!mounted) return;
      tituloProvaController.clear();
      descricaoProvaController.clear();
      notaProvaController.clear();
      pesoProvaController.text = '1.0';
      _dataCriacaoProva = null;
      _dataProva = null;
      _pdfAnexoSelecionado = null;
      await carregarProvas();
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao adicionar prova: $e');
    }
  }

  /// Marca a prova como realizada/pendente.
  /// Ao marcar como realizada, pede a nota obtida e a registra também
  /// na tabela de Notas para entrar nos cálculos de desempenho.
  Future<void> atualizarStatusProva(int index, bool? newValue) async {
    if (newValue == null) return;
    final prova = provas[index];

    if (newValue == true && !prova.realizada) {
      final nota = await _pedirNotaProva(prova);
      if (nota == null) return; // cancelado: não marca como realizada

      try {
        prova.realizada = true;
        prova.nota = nota;
        await provaService.atualizarProva(prova);
        if (!mounted) return;
        await carregarProvas();
        _mostrarSucesso('✅ Prova concluída! Nota $nota registrada em Notas.');
      } catch (e) {
        if (!mounted) return;
        _mostrarErro('Erro ao atualizar prova: $e');
      }
    } else {
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
  }

  Future<double?> _pedirNotaProva(Prova prova) async {
    final ctrl = TextEditingController();
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Qual foi a sua nota?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prova.titulo,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Peso: ${prova.peso.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '0.0 — 10.0',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              final valor = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (valor == null || valor < 0 || valor > 10) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Informe uma nota entre 0 e 10.')),
                );
                return;
              }
              Navigator.pop(ctx, valor);
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
<<<<<<< HEAD
    _pdfAnexoSelecionado = null;
=======
    _provaVinculadaTarefa = null;
    _prioridadeTarefa = prioridadeMedia;
>>>>>>> d0eecb2bc4e35bdc331f6b3043eb41990fc1b8ae

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
                    TextField(controller: tituloTarefaController, decoration: const InputDecoration(labelText: 'Título')),
                    const SizedBox(height: 10),
                    TextField(controller: descricaoTarefaController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição')),
                    const SizedBox(height: 16),
                    const Text('Prioridade',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _prioridadeTarefa,
                      items: const [
                        DropdownMenuItem(value: prioridadeBaixa, child: Text('🟢  Baixa')),
                        DropdownMenuItem(value: prioridadeMedia, child: Text('🟡  Média')),
                        DropdownMenuItem(value: prioridadeAlta,  child: Text('🔴  Alta')),
                      ],
                      onChanged: (v) => setDialogState(() => _prioridadeTarefa = v ?? prioridadeMedia),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
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
<<<<<<< HEAD
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          withData: true,
                        );
                        if (result != null && result.files.single.bytes != null) {
                          setDialogState(() {
                            _pdfAnexoSelecionado = result.files.single;
                          });
                        }
                      },
                      icon: Icon(_pdfAnexoSelecionado != null ? Icons.check_circle : Icons.picture_as_pdf, color: _pdfAnexoSelecionado != null ? Colors.green : null),
                      label: Text(
                        _pdfAnexoSelecionado != null ? 'PDF: ${_pdfAnexoSelecionado!.name}' : 'Anexar PDF (Opcional)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: BorderSide(color: _pdfAnexoSelecionado != null ? Colors.green : Colors.grey),
                        alignment: Alignment.centerLeft
                      ),
                    ),
=======
                    const SizedBox(height: 10),
                    if (provas.isNotEmpty) ...[
                      const Text('Vincular a uma prova (opcional)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<Prova?>(
                        value: _provaVinculadaTarefa,
                        items: [
                          const DropdownMenuItem<Prova?>(
                            value: null,
                            child: Text('Nenhuma'),
                          ),
                          ...provas.map((p) => DropdownMenuItem<Prova?>(
                                value: p,
                                child: Text(p.titulo, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setDialogState(() => _provaVinculadaTarefa = v),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ],
>>>>>>> d0eecb2bc4e35bdc331f6b3043eb41990fc1b8ae
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
    pesoProvaController.text = '1.0';
    _dataCriacaoProva = DateTime.now();
    _dataProva = null;
    _pdfAnexoSelecionado = null;

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
                      controller: pesoProvaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Peso da avaliação',
                        hintText: 'Ex: 1.0, 2.0...',
                        helperText: 'Usado no cálculo da média ponderada',
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          withData: true,
                        );
                        if (result != null && result.files.single.bytes != null) {
                          setDialogState(() {
                            _pdfAnexoSelecionado = result.files.single;
                          });
                        }
                      },
                      icon: Icon(_pdfAnexoSelecionado != null ? Icons.check_circle : Icons.picture_as_pdf, color: _pdfAnexoSelecionado != null ? Colors.green : null),
                      label: Text(
                        _pdfAnexoSelecionado != null ? 'PDF: ${_pdfAnexoSelecionado!.name}' : 'Anexar PDF (Opcional)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: BorderSide(color: _pdfAnexoSelecionado != null ? Colors.green : Colors.grey),
                        alignment: Alignment.centerLeft
                      ),
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
                _buildListaTarefas(),
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
        final provaVinculada = tarefa.idProva != null
            ? provas.where((p) => p.id == tarefa.idProva).firstOrNull
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      decoration: tarefa.concluida ? TextDecoration.lineThrough : null,
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
                Text('Peso: ${prova.peso.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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