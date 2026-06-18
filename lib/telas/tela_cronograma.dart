import 'package:flutter/material.dart';
import '../services/tarefa_service.dart';
import '../services/prova_service.dart';

class TimelineEvent {
  final DateTime date;
  final String title;
  final String description;
  final String type; // 'tarefa' or 'prova'
  final bool isCompleted;
  final String materiaNome;

  TimelineEvent({
    required this.date,
    required this.title,
    required this.description,
    required this.type,
    required this.isCompleted,
    this.materiaNome = '',
  });
}

class TelaCronograma extends StatefulWidget {
  const TelaCronograma({super.key});

  @override
  State<TelaCronograma> createState() => _TelaCronogramaState();
}

class _TelaCronogramaState extends State<TelaCronograma> {
  final TarefaService _tarefaService = TarefaService();
  final ProvaService _provaService = ProvaService();

  List<TimelineEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final tarefas = await _tarefaService.buscarTodas();
      final provas = await _provaService.buscarTodas();

      final List<TimelineEvent> events = [];

      for (var t in tarefas) {
        final date = t.dataEntrega ?? t.dataCriacao ?? DateTime.now();
        events.add(
          TimelineEvent(
            date: date,
            title: t.titulo,
            description: t.descricao,
            type: 'tarefa',
            isCompleted: t.concluida,
          ),
        );
      }

      for (var p in provas) {
        final date = p.dataProva ?? p.dataCriacao ?? DateTime.now();
        events.add(
          TimelineEvent(
            date: date,
            title: p.titulo,
            description: p.descricao,
            type: 'prova',
            isCompleted: p.realizada,
          ),
        );
      }

      events.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar cronograma: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Mapa Mental / Cronograma'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(
              child: Text(
                'Nenhum evento (tarefa ou prova) cadastrado.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : Stack(
              children: [
                // Linha central fixa para simular o mapa mental / timeline
                Positioned(
                  left: MediaQuery.of(context).size.width / 2 - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
                // Lista de eventos
                ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final bool isLeft = index % 2 == 0;
                    return _buildTimelineRow(event, isLeft);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildTimelineRow(TimelineEvent event, bool isLeft) {
    final card = _buildEventCard(event);
    final emptyHalf = Expanded(child: const SizedBox());
    final isProva = event.type == 'prova';

    // Cor do nó baseada no tipo e se foi concluída
    final dotColor = event.isCompleted
        ? Colors.grey.shade400
        : (isProva ? const Color(0xFFEF4444) : const Color(0xFF10B981));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isLeft)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: card,
              ),
            )
          else
            emptyHalf,

          // Nó central
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
              ],
            ),
          ),

          if (!isLeft)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: card,
              ),
            )
          else
            emptyHalf,
        ],
      ),
    );
  }

  Widget _buildEventCard(TimelineEvent event) {
    final isProva = event.type == 'prova';
    final cardColor = isProva
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    final opacityColor = event.isCompleted ? Colors.grey.shade400 : cardColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: opacityColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: opacityColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isProva
                      ? Icons.assignment_late_rounded
                      : Icons.task_alt_rounded,
                  size: 16,
                  color: opacityColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDateTime(event.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: opacityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: event.isCompleted
                    ? Colors.grey
                    : const Color(0xFF334155),
                decoration: event.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
