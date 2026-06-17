import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/materia.dart';
import '../models/prova.dart';
import '../models/documento.dart';
import '../services/materia_service.dart';
import '../services/prova_service.dart';
import '../services/nota_service.dart';
import '../services/gemini_service.dart';
import '../services/documento_service.dart';
import 'tela_detalhes_prova.dart';

class TelaProvas extends StatefulWidget {
  const TelaProvas({super.key});

  @override
  State<TelaProvas> createState() => _TelaProvasState();
}

class _TelaProvasState extends State<TelaProvas>
    with SingleTickerProviderStateMixin {
  final ProvaService _provaService = ProvaService();
  final NotaService _notaService = NotaService();
  final MateriaService _materiaService = MateriaService();
  final GeminiService _geminiService = GeminiService();
  final DocumentoService _documentoService = DocumentoService();

  List<Prova> _provasPendentes = [];
  List<Prova> _provasRealizadas = [];
  List<Materia> _materias = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarTodasProvas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Carregamento ──────────────────────────────────────────────────────────

  Future<void> _carregarTodasProvas() async {
    setState(() => _isLoading = true);
    try {
      final provas = await _provaService.buscarTodas();
      final materias = await _materiaService.buscarMaterias();
      if (!mounted) return;

      final pendentes = provas.where((p) => !p.realizada).toList();
      final realizadas = provas.where((p) => p.realizada).toList();

      pendentes.sort((a, b) {
        if (a.dataProva == null && b.dataProva == null) return 0;
        if (a.dataProva == null) return 1;
        if (b.dataProva == null) return -1;
        return a.dataProva!.compareTo(b.dataProva!);
      });

      realizadas.sort((a, b) {
        if (a.dataProva == null && b.dataProva == null) return 0;
        if (a.dataProva == null) return 1;
        if (b.dataProva == null) return -1;
        return b.dataProva!.compareTo(a.dataProva!);
      });

      setState(() {
        _provasPendentes = pendentes;
        _provasRealizadas = realizadas;
        _materias = materias;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar provas: $e')),
      );
    }
  }

  // ── Utilitários ───────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String? _nomeMateria(int idMateria) {
    return _materias
        .where((m) => m.id == idMateria)
        .map((m) => m.nome)
        .firstOrNull;
  }

  Color _corUrgencia(Prova prova) {
    if (prova.dataProva == null) return const Color(0xFF94A3B8);
    final diff = prova.dataProva!.difference(DateTime.now()).inDays;
    if (diff < 0) return const Color(0xFF94A3B8);
    if (diff == 0) return const Color(0xFFEF4444);
    if (diff <= 1) return const Color(0xFFF59E0B);
    if (diff <= 7) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  (String, Color) _contagemRegressiva(Prova prova) {
    if (prova.dataProva == null) {
      return ('Sem data definida', const Color(0xFF94A3B8));
    }
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final provaSemHora = DateTime(
        prova.dataProva!.year, prova.dataProva!.month, prova.dataProva!.day);
    final diff = provaSemHora.difference(hojeSemHora).inDays;

    if (diff < 0) return ('Passou há ${-diff} dia(s)', const Color(0xFF94A3B8));
    if (diff == 0) return ('🔥 HOJE!', const Color(0xFFEF4444));
    if (diff == 1) return ('⚠️ Amanhã!', const Color(0xFFF59E0B));
    if (diff <= 3) return ('⚠️ Em $diff dias', const Color(0xFFF59E0B));
    if (diff <= 7) return ('📅 Em $diff dias', const Color(0xFF3B82F6));
    return ('📅 Em $diff dias', const Color(0xFF10B981));
  }

  // ── IA & PDF ──────────────────────────────────────────────────────────────

  Future<void> _anexarPdf(Prova prova) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        _mostrarSucesso('Gerando resumo via IA, por favor aguarde...');

        final summary =
            await _geminiService.summarizePdf(result.files.single.bytes!);

        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final savedFile = File(path.join(appDir.path, fileName));
        await savedFile.writeAsBytes(result.files.single.bytes!);

        final novoDoc = Documento(
          titulo: 'Resumo: ${prova.titulo}',
          tipo: 'resumo',
          caminho: savedFile.path,
          nomeArquivo: result.files.single.name,
          resumo: summary,
          dataCriacao: DateTime.now().toIso8601String(),
          idProva: prova.id,
        );

        final docId = await _documentoService.insertDocumento(novoDoc);
        prova.documentoId = docId;
        await _provaService.atualizarProva(prova);
        await _carregarTodasProvas();
        _mostrarSucesso('Resumo gerado e anexado com sucesso!');
      }
    } catch (e) {
      _mostrarErro('Erro ao gerar resumo: $e');
    }
  }

  Future<void> _verResumo(int docId) async {
    try {
      final docs = await _documentoService.getDocumentos();
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

  // ── Ações sobre provas ────────────────────────────────────────────────────

  Future<void> _deletarProva(Prova prova) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remover prova?'),
        content: Text('Deseja remover "${prova.titulo}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _provaService.removerProva(prova.id!);
      if (prova.id != null) {
        await _notaService.removerNotaDaProva(prova.id!);
      }
      await _carregarTodasProvas();
      if (!mounted) return;
      _mostrarSucesso('Prova removida!');
    } catch (e) {
      if (!mounted) return;
      _mostrarErro('Erro ao remover prova: $e');
    }
  }

  Future<void> _marcarRealizada(Prova prova) async {
    if (!prova.realizada) {
      final nota = await _pedirNota(prova);
      if (nota == null) return;

      try {
        prova.realizada = true;
        prova.nota = nota;
        await _provaService.atualizarProva(prova);
        await _notaService.salvarNotaDaProva(prova, nota);
        await _carregarTodasProvas();
        if (!mounted) return;
        _mostrarSucesso('✅ Prova concluída! Nota $nota registrada.');
      } catch (e) {
        if (!mounted) return;
        _mostrarErro('Erro ao atualizar prova: $e');
      }
    } else {
      try {
        prova.realizada = false;
        prova.nota = null;
        await _provaService.atualizarProva(prova);
        if (prova.id != null) await _notaService.removerNotaDaProva(prova.id!);
        await _carregarTodasProvas();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prova marcada como pendente'),
            backgroundColor: Color(0xFF64748B),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _mostrarErro('Erro ao atualizar prova: $e');
      }
    }
  }

  Future<double?> _pedirNota(Prova prova) async {
    final ctrl = TextEditingController();
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Qual foi a sua nota?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prova.titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text('Peso da avaliação: ${prova.peso.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0.0 — 10.0',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Essa nota será salva automaticamente em Notas e usada nos cálculos de desempenho.',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final valor =
                  double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (valor == null || valor < 0 || valor > 10) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Informe uma nota válida entre 0 e 10.'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, valor);
            },
            child: const Text('Salvar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Dialog Nova Prova ─────────────────────────────────────────────────────
  // CORRIGIDO: todas as variáveis de estado do formulário são locais ao
  // StatefulBuilder — elimina o bug onde o dialog não refletia mudanças.

  void _abrirDialogNovaProva() {
  if (_materias.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cadastre pelo menos uma matéria antes de adicionar uma prova.',
        ),
        backgroundColor: Color(0xFFF59E0B),
      ),
    );
    return;
  }

  final tituloCtrl = TextEditingController();
  final descricaoCtrl = TextEditingController();
  final pesoCtrl = TextEditingController(text: '1.0');

  DateTime? dataProva;
  Materia materiaSelecionada = _materias.first;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Nova Prova',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),

            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    DropdownButtonFormField<Materia>(
                      value: materiaSelecionada,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Matéria',
                        border: OutlineInputBorder(),
                      ),
                      items: _materias.map((materia) {
                        return DropdownMenuItem<Materia>(
                          value: materia,
                          child: Text(
                            materia.nome,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (materia) {
                        if (materia != null) {
                          setDialogState(() {
                            materiaSelecionada = materia;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome da prova',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: descricaoCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Peso',
                        hintText: 'Ex: 1.0, 2.0, 3.0',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    InkWell(
                      onTap: () async {
                        final data = await showDatePicker(
                          context: dialogContext,
                          initialDate: dataProva ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (data != null) {
                          setDialogState(() {
                            dataProva = data;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data da prova',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(
                          dataProva == null
                              ? 'Selecionar data'
                              : _formatDate(dataProva!),
                          style: TextStyle(
                            color: dataProva == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (tituloCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Informe o nome da prova.'),
                      ),
                    );
                    return;
                  }

                  final peso = double.tryParse(
                    pesoCtrl.text.trim().replaceAll(',', '.'),
                  );

                  if (peso == null || peso <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Informe um peso válido.'),
                      ),
                    );
                    return;
                  }

                  try {
                    final prova = Prova(
                      titulo: tituloCtrl.text.trim(),
                      descricao: descricaoCtrl.text.trim(),
                      realizada: false,
                      idMateria: materiaSelecionada.id!,
                      dataCriacao: DateTime.now(),
                      dataProva: dataProva,
                      peso: peso,
                    );

                    await _provaService.inserirProva(prova);

                    if (!mounted) return;

                    Navigator.pop(dialogContext);

                    await _carregarTodasProvas();

                    if (!mounted) return;

                    _mostrarSucesso('Prova adicionada!');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao salvar prova: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );
}

  void _abrirDetalhes(Prova prova) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TelaDetalhesProva(provaId: prova.id!)),
    );
    _carregarTodasProvas();
  }

  // ── Feedback ──────────────────────────────────────────────────────────────

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _mostrarSucesso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Provas'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFEF4444),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFEF4444),
          tabs: [
            Tab(
              text: 'Pendentes (${_provasPendentes.length})',
              icon: const Icon(Icons.pending_rounded, size: 18),
            ),
            Tab(
              text: 'Realizadas (${_provasRealizadas.length})',
              icon: const Icon(Icons.verified_rounded, size: 18),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListaPendentes(),
                _buildListaRealizadas(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogNovaProva,
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        tooltip: 'Nova Prova',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // ── Listas ────────────────────────────────────────────────────────────────

  Widget _buildListaPendentes() {
    if (_provasPendentes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration_rounded,
                size: 80, color: Color(0xFF10B981)),
            const SizedBox(height: 16),
            Text(
              'Nenhuma prova pendente!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Você está em dia com as provas.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque no + para adicionar uma nova prova.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCBD5E1),
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarTodasProvas,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _provasPendentes.length,
        itemBuilder: (context, index) =>
            _buildCardProva(_provasPendentes[index]),
      ),
    );
  }

  Widget _buildListaRealizadas() {
    if (_provasRealizadas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_rounded,
                size: 80, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            Text(
              'Nenhuma prova realizada ainda.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarTodasProvas,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _provasRealizadas.length,
        itemBuilder: (context, index) =>
            _buildCardProva(_provasRealizadas[index]),
      ),
    );
  }

  // ── Card unificado (igual ao da tela de matérias) ─────────────────────────

  Widget _buildCardProva(Prova prova) {
    final nomMateria = _nomeMateria(prova.idMateria);
    final corUrgencia = _corUrgencia(prova);
    final (textoContagem, corContagem) = _contagemRegressiva(prova);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: prova.realizada
            ? BorderSide.none
            : BorderSide(
                color: corUrgencia.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF4F46E5),
              value: prova.realizada,
              onChanged: (_) => _marcarRealizada(prova),
              title: Text(
                prova.titulo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration:
                      prova.realizada ? TextDecoration.lineThrough : null,
                  color: prova.realizada
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1E293B),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (prova.descricao.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        prova.descricao,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (nomMateria != null)
                    Text(
                      nomMateria,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              secondary: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PDF / Resumo
                  if (prova.documentoId != null)
                    IconButton(
                      icon: const Icon(Icons.description,
                          color: Color(0xFF8B5CF6)),
                      onPressed: () => _verResumo(prova.documentoId!),
                      tooltip: 'Ver Resumo',
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf,
                          color: Color(0xFF64748B)),
                      onPressed: () => _anexarPdf(prova),
                      tooltip: 'Anexar PDF (IA)',
                    ),
                  // Detalhes
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded,
                        color: Color(0xFF4F46E5), size: 20),
                    onPressed: () => _abrirDetalhes(prova),
                    tooltip: 'Ver detalhes',
                  ),
                  // Deletar
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deletarProva(prova),
                    tooltip: 'Remover prova',
                  ),
                ],
              ),
            ),
            // Chips de informação
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (!prova.realizada) ...[
                    if (prova.dataProva != null)
                      _buildChip(
                        '📅 ${_formatDate(prova.dataProva!)}',
                        const Color(0xFF64748B),
                      ),
                    _buildChip(textoContagem, corContagem),
                  ],
                  if (prova.realizada && prova.dataProva != null)
                    _buildChip(
                      '📅 ${_formatDate(prova.dataProva!)}',
                      const Color(0xFF94A3B8),
                    ),
                  _buildChip('Peso ${prova.peso.toStringAsFixed(1)}',
                      const Color(0xFF8B5CF6)),
                  if (prova.nota != null)
                    _buildChip(
                      '🏆 Nota: ${prova.nota!.toStringAsFixed(1)}',
                      prova.nota! >= 6
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  if (prova.realizada && prova.nota == null)
                    _buildChip('Sem nota registrada', const Color(0xFF94A3B8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String texto, Color cor, {IconData? icone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
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
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}