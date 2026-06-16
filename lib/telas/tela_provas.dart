import 'package:flutter/material.dart';
import '../models/materia.dart';
import '../models/prova.dart';
import '../services/materia_service.dart';
import '../services/prova_service.dart';
import '../services/nota_service.dart';
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

  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _pesoController = TextEditingController(text: '1.0');

  List<Prova> _provasPendentes = [];
  List<Prova> _provasRealizadas = [];
  List<Materia> _materias = [];
  bool _isLoading = true;
  DateTime? _dataProva;
  Materia? _materiaSelecionada;
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
    _tituloController.dispose();
    _descricaoController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  (String, Color) _contageRegressiva(Prova prova) {
    if (prova.dataProva == null) {
      return ('Sem data definida', const Color(0xFF94A3B8));
    }

    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final provaSemHora = DateTime(
      prova.dataProva!.year,
      prova.dataProva!.month,
      prova.dataProva!.day,
    );
    final diff = provaSemHora.difference(hojeSemHora).inDays;

    if (diff < 0) {
      return ('Passou há ${-diff} dia(s)', const Color(0xFF94A3B8));
    } else if (diff == 0) {
      return ('🔥 HOJE!', const Color(0xFFEF4444));
    } else if (diff == 1) {
      return ('⚠️ Amanhã!', const Color(0xFFF59E0B));
    } else if (diff <= 3) {
      return ('⚠️ Em $diff dias', const Color(0xFFF59E0B));
    } else if (diff <= 7) {
      return ('📅 Em $diff dias', const Color(0xFF3B82F6));
    } else {
      return ('📅 Em $diff dias', const Color(0xFF10B981));
    }
  }

  Color _corUrgencia(Prova prova) {
    if (prova.dataProva == null) return const Color(0xFF94A3B8);
    final hoje = DateTime.now();
    final diff = prova.dataProva!.difference(hoje).inDays;
    if (diff < 0) return const Color(0xFF94A3B8);
    if (diff == 0) return const Color(0xFFEF4444);
    if (diff <= 1) return const Color(0xFFF59E0B);
    if (diff <= 7) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  void _abrirDialogNovaProva() {
    if (_materias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cadastre pelo menos uma matéria antes de adicionar uma prova.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    _tituloController.clear();
    _descricaoController.clear();
    _pesoController.text = '1.0';
    _dataProva = null;
    _materiaSelecionada = _materias.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nova Prova',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Matéria
                const Text('Matéria *',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                DropdownButtonFormField<Materia>(
                  value: _materiaSelecionada,
                  items: _materias
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: m.cor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(m.nome,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setDs(() => _materiaSelecionada = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Título
                TextField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Descrição
                TextField(
                  controller: _descricaoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Data
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Data da Prova',
                      style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    _dataProva != null
                        ? _formatDate(_dataProva!)
                        : 'Toque para selecionar',
                    style: const TextStyle(color: Color(0xFF4F46E5)),
                  ),
                  trailing: const Icon(Icons.event_rounded,
                      size: 18, color: Color(0xFF4F46E5)),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: _dataProva ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setDs(() => _dataProva = p);
                  },
                ),
                const SizedBox(height: 8),
                // Peso
                TextField(
                  controller: _pesoController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso da avaliação',
                    hintText: 'Ex: 1.0, 2.0...',
                    helperText: 'Usado no cálculo da média ponderada',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (_tituloController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Informe o título da prova.')),
                  );
                  return;
                }
                if (_materiaSelecionada == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Selecione uma matéria.')),
                  );
                  return;
                }
                final peso = double.tryParse(
                        _pesoController.text.trim().replaceAll(',', '.')) ??
                    1.0;
                try {
                  final prova = Prova(
                    titulo: _tituloController.text.trim(),
                    descricao: _descricaoController.text.trim(),
                    realizada: false,
                    idMateria: _materiaSelecionada!.id!,
                    dataCriacao: DateTime.now(),
                    dataProva: _dataProva,
                    peso: peso,
                  );
                  await _provaService.inserirProva(prova);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _carregarTodasProvas();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prova adicionada!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Erro ao salvar prova: $e')),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDetalhes(Prova prova) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaDetalhesProva(provaId: prova.id!)),
    );
    _carregarTodasProvas();
  }

  /// Ao marcar como realizada, pede a nota obtida e salva também na tabela de Notas
  Future<void> _marcarRealizada(Prova prova) async {
    if (!prova.realizada) {
      // Vai marcar como realizada — pede a nota
      final nota = await _pedirNota(prova);
      if (nota == null) return; // usuário cancelou

      try {
        prova.realizada = true;
        prova.nota = nota;
        await _provaService.atualizarProva(prova);

        // Salva também em Notas para entrar nos cálculos de desempenho
        await _notaService.salvarNotaDaProva(prova, nota);

        await _carregarTodasProvas();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Prova concluída! Nota $nota registrada.'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar prova: $e')),
        );
      }
    } else {
      // Reverter para pendente
      try {
        prova.realizada = false;
        prova.nota = null;
        await _provaService.atualizarProva(prova);
        if (prova.id != null) {
          await _notaService.removerNotaDaProva(prova.id!);
        }
        await _carregarTodasProvas();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prova marcada como pendente'),
            backgroundColor: Color(0xFF64748B),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar prova: $e')),
        );
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
            Text(
              prova.titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Peso da avaliação: ${prova.peso.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        itemBuilder: (context, index) {
          return _buildCardPendente(_provasPendentes[index]);
        },
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
        itemBuilder: (context, index) {
          return _buildCardRealizada(_provasRealizadas[index]);
        },
      ),
    );
  }

  Widget _buildCardPendente(Prova prova) {
    final (textoContagem, corContagem) = _contageRegressiva(prova);
    final corUrgencia = _corUrgencia(prova);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: corUrgencia.withValues(alpha: 0.3), width: 1.5),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirDetalhes(prova),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: corUrgencia.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_late_rounded,
                      color: corUrgencia,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prova.titulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (prova.descricao.isNotEmpty)
                          Text(
                            prova.descricao,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF10B981)),
                    tooltip: 'Marcar como realizada',
                    onPressed: () => _marcarRealizada(prova),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (prova.dataProva != null)
                    _buildChip(
                      '📅 ${_formatDate(prova.dataProva!)}',
                      const Color(0xFF64748B),
                    ),
                  _buildChip(textoContagem, corContagem),
                  _buildChip('Peso ${prova.peso.toStringAsFixed(1)}',
                      const Color(0xFF8B5CF6)),
                  TextButton.icon(
                    onPressed: () => _abrirDetalhes(prova),
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: const Text('Detalhes', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardRealizada(Prova prova) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      color: const Color(0xFFF8FAFC),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirDetalhes(prova),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prova.titulo,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF475569),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        if (prova.descricao.isNotEmpty)
                          Text(
                            prova.descricao,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.undo_rounded,
                        color: Color(0xFF94A3B8)),
                    tooltip: 'Marcar como pendente',
                    onPressed: () => _marcarRealizada(prova),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (prova.dataProva != null)
                    _buildChip(
                      '📅 ${_formatDate(prova.dataProva!)}',
                      const Color(0xFF94A3B8),
                    ),
                  if (prova.nota != null)
                    _buildChip(
                      '🏆 Nota: ${prova.nota!.toStringAsFixed(1)}',
                      prova.nota! >= 6
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  if (prova.nota == null)
                    _buildChip('Sem nota registrada', const Color(0xFF94A3B8)),
                  _buildChip('Peso ${prova.peso.toStringAsFixed(1)}',
                      const Color(0xFF8B5CF6)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }
}