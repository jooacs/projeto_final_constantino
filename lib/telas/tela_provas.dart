import 'package:flutter/material.dart';
import '../models/prova.dart';
import '../services/prova_service.dart';

class TelaProvas extends StatefulWidget {
  const TelaProvas({super.key});

  @override
  State<TelaProvas> createState() => _TelaProvasState();
}

class _TelaProvasState extends State<TelaProvas> {
  final ProvaService _provaService = ProvaService();
  List<Prova> _provas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarTodasProvas();
  }

  Future<void> _carregarTodasProvas() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final provas = await _provaService.buscarTodas();
      if (!mounted) return;
      setState(() {
        _provas = provas;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar provas: $e')),
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
        title: const Text('Todas as Provas'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _provas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_late_rounded, size: 80, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma prova cadastrada no total.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _provas.length,
                  itemBuilder: (context, index) {
                    final prova = _provas[index];

                    String datasTexto = '';
                    if (prova.dataProva != null) {
                      datasTexto += 'Data da Prova: ${_formatDate(prova.dataProva!)}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: prova.realizada ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            prova.realizada ? Icons.verified_rounded : Icons.pending_rounded,
                            color: prova.realizada ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        title: Text(
                          prova.titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: prova.realizada ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (prova.descricao.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Text(prova.descricao),
                              ),
                            if (datasTexto.isNotEmpty)
                              Text(
                                datasTexto,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            if (prova.nota != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Nota: ${prova.nota}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
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
