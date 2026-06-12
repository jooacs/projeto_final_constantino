import 'package:flutter/material.dart';
import '../models/tarefa.dart';
import '../services/tarefa_service.dart';
import '../database/db_constants.dart';

class TelaTarefas extends StatefulWidget {
  const TelaTarefas({super.key});

  @override
  State<TelaTarefas> createState() => _TelaTarefasState();
}

class _TelaTarefasState extends State<TelaTarefas> {
  final TarefaService _tarefaService = TarefaService();
  List<Tarefa> _tarefas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarTodasTarefas();
  }

  Future<void> _carregarTodasTarefas() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final tarefas = await _tarefaService.buscarTodas();
      if (!mounted) return;
      setState(() {
        _tarefas = tarefas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar tarefas: $e')));
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

    if (diff < 0) return const Color(0xFFEF4444); // atrasada
    if (diff <= 1) return const Color(0xFFF59E0B); // hoje/amanhã
    return const Color(0xFF10B981); // tranquilo
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Todas as Tarefas'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tarefas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.task_alt_rounded,
                    size: 80,
                    color: Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma tarefa cadastrada no total.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _tarefas.length,
              itemBuilder: (context, index) {
                final tarefa = _tarefas[index];

                String datasTexto = '';
                if (tarefa.dataEntrega != null) {
                  datasTexto = 'Entrega: ${_formatDate(tarefa.dataEntrega!)}';
                } else if (tarefa.dataCriacao != null) {
                  datasTexto = 'Criado em: ${_formatDate(tarefa.dataCriacao!)}';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tarefa.concluida
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : const Color(0xFFF59E0B).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tarefa.concluida
                            ? Icons.check_circle_rounded
                            : Icons.pending_actions_rounded,
                        color: tarefa.concluida
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
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
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(tarefa.descricao),
                          ),
                        if (datasTexto.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              datasTexto,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
