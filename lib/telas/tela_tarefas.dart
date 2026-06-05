import 'package:flutter/material.dart';
import '../models/tarefa.dart';
import '../services/tarefa_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar tarefas: $e')),
      );
    }
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
                      const Icon(Icons.task_alt_rounded, size: 80, color: Color(0xFFE2E8F0)),
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
                      datasTexto += 'Entrega: ${_formatDate(tarefa.dataEntrega!)}';
                    } else if (tarefa.dataCriacao != null) {
                      datasTexto += 'Criado em: ${_formatDate(tarefa.dataCriacao!)}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tarefa.concluida ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            tarefa.concluida ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                            color: tarefa.concluida ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                        title: Text(
                          tarefa.titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: tarefa.concluida ? TextDecoration.lineThrough : null,
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
                              Text(
                                datasTexto,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
