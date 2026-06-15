import 'package:flutter/material.dart';
import '../models/prova.dart';
import '../models/tarefa.dart';
import '../services/prova_service.dart';
import '../services/tarefa_service.dart';

class TelaProvas extends StatefulWidget {
  const TelaProvas({super.key});

  @override
  State<TelaProvas> createState() => _TelaProvasState();
}

class _TelaProvasState extends State<TelaProvas>
    with SingleTickerProviderStateMixin {
  final ProvaService _provaService = ProvaService();
  final TarefaService _tarefaService = TarefaService();

  List<Prova> _provasPendentes = [];
  List<Prova> _provasRealizadas = [];
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

  Future<void> _carregarTodasProvas() async {
    setState(() => _isLoading = true);
    try {
      final provas = await _provaService.buscarTodas();
      if (!mounted) return;

      // Ordenar por data (mais próximas primeiro)
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
        return b.dataProva!.compareTo(a.dataProva!); // mais recentes primeiro
      });

      setState(() {
        _provasPendentes = pendentes;
        _provasRealizadas = realizadas;
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

  /// Retorna texto e cor da contagem regressiva
  (String, Color) _contageRegressiva(Prova prova) {
    if (prova.dataProva == null) {
      return ('Sem data definida', const Color(0xFF94A3B8));
    }

    final hoje = DateTime.now();
    final hojeSemHora =
        DateTime(hoje.year, hoje.month, hoje.day);
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

  Future<void> _verTarefasRelacionadas(Prova prova) async {
    try {
      final tarefas = await _tarefaService.buscarPorMateria(prova.idMateria);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _TarefasRelacionadasSheet(
          prova: prova,
          tarefas: tarefas,
          formatDate: _formatDate,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar tarefas: $e')),
      );
    }
  }

  Future<void> _marcarRealizada(Prova prova) async {
    try {
      prova.realizada = !prova.realizada;
      await _provaService.atualizarProva(prova);
      await _carregarTodasProvas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              prova.realizada ? '✅ Prova marcada como realizada!' : 'Prova marcada como pendente'),
          backgroundColor:
              prova.realizada ? const Color(0xFF10B981) : const Color(0xFF64748B),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar prova: $e')),
      );
    }
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
        onTap: () => _verTarefasRelacionadas(prova),
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
              Row(
                children: [
                  if (prova.dataProva != null) ...[
                    _buildChip(
                      '📅 ${_formatDate(prova.dataProva!)}',
                      const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildChip(textoContagem, corContagem),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _verTarefasRelacionadas(prova),
                    icon: const Icon(Icons.task_alt_rounded, size: 14),
                    label: const Text('Tarefas', style: TextStyle(fontSize: 12)),
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
        onTap: () => _verTarefasRelacionadas(prova),
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

class _TarefasRelacionadasSheet extends StatelessWidget {
  final Prova prova;
  final List<Tarefa> tarefas;
  final String Function(DateTime) formatDate;

  const _TarefasRelacionadasSheet({
    required this.prova,
    required this.tarefas,
    required this.formatDate,
  });

  Color _corPrioridade(String prioridade) {
    switch (prioridade) {
      case 'alta':
        return const Color(0xFFEF4444);
      case 'baixa':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _labelPrioridade(String prioridade) {
    switch (prioridade) {
      case 'alta':
        return 'Alta';
      case 'baixa':
        return 'Baixa';
      default:
        return 'Média';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = tarefas.where((t) => !t.concluida).toList();
    final concluidas = tarefas.where((t) => t.concluida).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.assignment_late_rounded,
                              color: Color(0xFFEF4444), size: 20),
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
                                  fontSize: 18,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (prova.dataProva != null)
                                Text(
                                  '📅 ${formatDate(prova.dataProva!)}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tarefas relacionadas a esta matéria',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              // Lista de tarefas
              Expanded(
                child: tarefas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma tarefa nesta matéria',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          if (pendentes.isNotEmpty) ...[
                            _buildSectionHeader(
                                'Pendentes (${pendentes.length})',
                                const Color(0xFFF59E0B)),
                            ...pendentes.map((t) => _buildTarefaTile(t)),
                            const SizedBox(height: 8),
                          ],
                          if (concluidas.isNotEmpty) ...[
                            _buildSectionHeader(
                                'Concluídas (${concluidas.length})',
                                const Color(0xFF10B981)),
                            ...concluidas.map((t) => _buildTarefaTile(t)),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarefaTile(Tarefa tarefa) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tarefa.concluida
            ? const Color(0xFFF8FAFC)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tarefa.concluida
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            tarefa.concluida
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: tarefa.concluida
                ? const Color(0xFF10B981)
                : const Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tarefa.titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: tarefa.concluida
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                    decoration: tarefa.concluida
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (tarefa.dataEntrega != null)
                  Text(
                    'Entrega: ${formatDate(tarefa.dataEntrega!)}',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 11),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _corPrioridade(tarefa.prioridade)
                  .withValues(alpha: 0.12),
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
        ],
      ),
    );
  }
}