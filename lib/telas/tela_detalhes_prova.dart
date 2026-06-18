import 'package:flutter/material.dart';
import '../models/prova.dart';
import '../models/tarefa.dart';
import '../models/documento.dart';
import '../models/materia.dart';
import '../services/prova_service.dart';
import '../services/tarefa_service.dart';
import '../services/documento_service.dart';
import '../services/nota_service.dart';
import '../services/materia_service.dart';
import '../database/db_constants.dart';

class TelaDetalhesProva extends StatefulWidget {
  final int provaId;

  const TelaDetalhesProva({super.key, required this.provaId});

  @override
  State<TelaDetalhesProva> createState() => _TelaDetalhesProvaState();
}

class _TelaDetalhesProvaState extends State<TelaDetalhesProva> {
  final _provaService = ProvaService();
  final _tarefaService = TarefaService();
  final _documentoService = DocumentoService();
  final _notaService = NotaService();
  final _materiaService = MateriaService();

  Prova? _prova;
  List<Tarefa> _tarefas = [];
  List<Documento> _resumos = [];
  List<Materia> _materias = [];
  bool _isLoading = true;

  // Controllers para adicionar tarefa
  final _tituloTarefaCtrl = TextEditingController();
  final _descricaoTarefaCtrl = TextEditingController();
  DateTime? _dataEntregaTarefa;
  String _prioridadeTarefa = prioridadeMedia;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _tituloTarefaCtrl.dispose();
    _descricaoTarefaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    try {
      final prova = await _provaService.buscarPorId(widget.provaId);
      if (prova == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        _tarefaService.buscarPorProva(prova.id!),
        _documentoService.buscarPorProva(prova.id!),
        _materiaService.buscarMaterias(),
      ]);

      if (!mounted) return;
      setState(() {
        _prova = prova;
        _tarefas = results[0] as List<Tarefa>;
        _resumos = results[1] as List<Documento>;
        _materias = results[2] as List<Materia>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar detalhes: $e')));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  double get _percentualPreparo {
    if (_tarefas.isEmpty) return 0;
    final concluidas = _tarefas.where((t) => t.concluida).length;
    return concluidas / _tarefas.length;
  }

  Color _corPreparo(double pct) {
    if (pct >= 0.8) return const Color(0xFF10B981);
    if (pct >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
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

  Future<void> _alternarTarefa(Tarefa tarefa) async {
    try {
      tarefa.concluida = !tarefa.concluida;
      tarefa.dataConclusao = tarefa.concluida ? DateTime.now() : null;
      await _tarefaService.atualizarTarefa(tarefa);
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao atualizar tarefa: $e')));
    }
  }

  Future<void> _deletarTarefa(Tarefa tarefa) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover tarefa?'),
        content: Text('Remover "${tarefa.titulo}" desta prova?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _tarefaService.removerTarefa(tarefa.id!);
      await _carregar();
    }
  }

  void _abrirDialogAdicionarTarefa() {
    final prova = _prova!;
    _tituloTarefaCtrl.clear();
    _descricaoTarefaCtrl.clear();
    _dataEntregaTarefa = null;
    _prioridadeTarefa = prioridadeMedia;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Nova Tarefa',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _tituloTarefaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descricaoTarefaCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Prioridade
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
                      child: Text('Baixa'),
                    ),
                    DropdownMenuItem(
                      value: prioridadeMedia,
                      child: Text('Média'),
                    ),
                    DropdownMenuItem(
                      value: prioridadeAlta,
                      child: Text('Alta'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDs(() => _prioridadeTarefa = v ?? prioridadeMedia),
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
                // Data de entrega
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Data de entrega (opcional)',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    _dataEntregaTarefa != null
                        ? _formatDate(_dataEntregaTarefa!)
                        : 'Toque para selecionar',
                    style: const TextStyle(color: Color(0xFF4F46E5)),
                  ),
                  trailing: const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: Color(0xFF4F46E5),
                  ),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: _dataEntregaTarefa ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setDs(() => _dataEntregaTarefa = p);
                  },
                ),
                // Chip indicando vinculação automática
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Vinculada à prova: ${prova.titulo}',
                          style: const TextStyle(
                            fontSize: 11,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (_tituloTarefaCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Informe o título da tarefa.'),
                    ),
                  );
                  return;
                }
                try {
                  final tarefa = Tarefa(
                    titulo: _tituloTarefaCtrl.text.trim(),
                    descricao: _descricaoTarefaCtrl.text.trim(),
                    concluida: false,
                    idMateria: prova.idMateria,
                    dataCriacao: DateTime.now(),
                    dataEntrega: _dataEntregaTarefa,
                    prioridade: _prioridadeTarefa,
                    idProva: prova.id,
                  );
                  await _tarefaService.inserirTarefa(tarefa);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _carregar();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tarefa adicionada!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Marca prova como realizada usando salvarNotaDaProva (evita duplicatas) ──
  Future<void> _marcarRealizada() async {
    final prova = _prova!;
    if (!prova.realizada) {
      final nota = await _pedirNota(prova);
      if (nota == null) return;

      try {
        prova.realizada = true;
        prova.nota = nota;
        await _provaService.atualizarProva(prova);

        // Usa salvarNotaDaProva para criar/atualizar sem duplicar
        await _notaService.salvarNotaDaProva(prova, nota);

        await _carregar();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Prova concluída! Nota $nota registrada.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } else {
      try {
        prova.realizada = false;
        prova.nota = null;
        await _provaService.atualizarProva(prova);
        // Remove a nota vinculada
        if (prova.id != null) {
          await _notaService.removerNotaDaProva(prova.id!);
        }
        await _carregar();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prova marcada como pendente')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Qual foi a sua nota?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
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
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final valor = double.tryParse(
                ctrl.text.trim().replaceAll(',', '.'),
              );
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
            child: const Text(
              'Salvar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _apagarProva() async {
    final prova = _prova;

    if (prova == null || prova.id == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Apagar prova?'),
          content: Text(
            'Tem certeza que deseja apagar "${prova.titulo}"?\n\n'
            'As tarefas vinculadas a essa prova e a nota registrada também serão removidas.',
          ),
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
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) return;

    try {
      // Remove a nota vinculada à prova
      await _notaService.removerNotaDaProva(prova.id!);

      // Remove tarefas vinculadas à prova
      for (final tarefa in _tarefas) {
        if (tarefa.id != null) {
          await _tarefaService.removerTarefa(tarefa.id!);
        }
      }

      // Remove a prova
      await _provaService.removerProva(prova.id!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prova apagada com sucesso!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao apagar prova: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_prova == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prova não encontrada')),
        body: const Center(child: Text('Esta prova não existe mais.')),
      );
    }

    final prova = _prova!;
    final pct = _percentualPreparo;
    final corPreparo = _corPreparo(pct);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Detalhes da Prova'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Apagar prova',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: _apagarProva,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCardPrincipal(prova),
            const SizedBox(height: 16),
            _buildProgressoPreparo(pct, corPreparo),
            const SizedBox(height: 24),

            // Seção Tarefas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSecaoTitulo(
                  '📋 Tarefas Relacionadas',
                  '${_tarefas.length}',
                ),
                TextButton.icon(
                  onPressed: _abrirDialogAdicionarTarefa,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Adicionar',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tarefas.isEmpty)
              _buildVazio(
                'Nenhuma tarefa vinculada.\nToque em "Adicionar" para criar uma.',
              )
            else
              ..._tarefas.map((t) => _buildTarefaTile(t)),

            const SizedBox(height: 24),

            _buildSecaoTitulo('📄 Resumos Relacionados', '${_resumos.length}'),
            const SizedBox(height: 12),
            if (_resumos.isEmpty)
              _buildVazio('Nenhum resumo vinculado a esta prova.')
            else
              ..._resumos.map((d) => _buildResumoTile(d)),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _marcarRealizada,
        backgroundColor: prova.realizada
            ? const Color(0xFF94A3B8)
            : const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: Icon(
          prova.realizada ? Icons.undo_rounded : Icons.check_circle_rounded,
        ),
        label: Text(prova.realizada ? 'Marcar pendente' : 'Marcar realizada'),
      ),
    );
  }

  Widget _buildCardPrincipal(Prova prova) {
    final nomMateria = _materias
        .where((m) => m.id == prova.idMateria)
        .map((m) => m.nome)
        .firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: prova.realizada
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (prova.realizada
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444))
                    .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                prova.realizada
                    ? Icons.verified_rounded
                    : Icons.assignment_late_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prova.titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (prova.descricao.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              prova.descricao,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (nomMateria != null)
                _buildInfoPill(Icons.menu_book_rounded, nomMateria),
              _buildInfoPill(
                Icons.event_rounded,
                prova.dataProva != null
                    ? _formatDate(prova.dataProva!)
                    : 'Sem data',
              ),
              _buildInfoPill(
                Icons.balance_rounded,
                'Peso ${prova.peso.toStringAsFixed(1)}',
              ),
              _buildInfoPill(
                prova.realizada
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                prova.realizada ? 'Realizada' : 'Pendente',
              ),
              if (prova.realizada && prova.nota != null)
                _buildInfoPill(
                  Icons.star_rounded,
                  'Nota: ${prova.nota!.toStringAsFixed(1)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressoPreparo(double pct, Color cor) {
    final concluidas = _tarefas.where((t) => t.concluida).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🎯 Preparação para a prova',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: cor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(cor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tarefas.isEmpty
                ? 'Toque em "Adicionar" acima para criar tarefas de preparação.'
                : '$concluidas de ${_tarefas.length} tarefas concluídas',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoTitulo(String title, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVazio(String texto) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
    );
  }

  Widget _buildTarefaTile(Tarefa tarefa) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: CheckboxListTile(
        value: tarefa.concluida,
        activeColor: const Color(0xFF10B981),
        onChanged: (_) => _alternarTarefa(tarefa),
        title: Text(
          tarefa.titulo,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: tarefa.concluida ? TextDecoration.lineThrough : null,
            color: tarefa.concluida
                ? const Color(0xFF94A3B8)
                : const Color(0xFF1E293B),
          ),
        ),
        subtitle: tarefa.descricao.isNotEmpty
            ? Text(
                tarefa.descricao,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              )
            : null,
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _corPrioridade(
                  tarefa.prioridade,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _labelPrioridade(tarefa.prioridade),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _corPrioridade(tarefa.prioridade),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              onPressed: () => _deletarTarefa(tarefa),
              tooltip: 'Remover',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoTile(Documento doc) {
    final isQuiz = doc.tipo == 'quiz';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isQuiz
              ? const Color(0xFFEC4899).withValues(alpha: 0.1)
              : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
          child: Icon(
            isQuiz ? Icons.quiz_rounded : Icons.text_snippet_rounded,
            color: isQuiz ? const Color(0xFFEC4899) : const Color(0xFF8B5CF6),
          ),
        ),
        title: Text(
          doc.titulo,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isQuiz ? 'Quiz' : 'Resumo',
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
