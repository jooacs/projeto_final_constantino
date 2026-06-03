import 'package:flutter/material.dart';

import '../models/materia.dart';
import '../models/tarefa.dart';
import '../services/tarefa_service.dart';

class TelaDetalhesMateria extends StatefulWidget {
  final Materia materia;

  const TelaDetalhesMateria({super.key, required this.materia});

  @override
  State<TelaDetalhesMateria> createState() => _TelaDetalhesMateriaState();
}

class _TelaDetalhesMateriaState extends State<TelaDetalhesMateria> {
  final TarefaService tarefaService = TarefaService();

  final tituloController = TextEditingController();
  final descricaoController = TextEditingController();

  List<Tarefa> tarefas = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    carregarTarefas();
  }

  @override
  void dispose() {
    tituloController.dispose();
    descricaoController.dispose();
    super.dispose();
  }

  Future<void> carregarTarefas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lista = await tarefaService.buscarPorMateria(widget.materia.id!);

      if (!mounted) return;

      setState(() {
        tarefas = lista;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erro ao carregar tarefas: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> adicionarTarefa() async {
    if (tituloController.text.trim().isEmpty) {
      _mostrarErro('Preencha o título da tarefa');
      return;
    }

    try {
      final tarefa = Tarefa(
        titulo: tituloController.text.trim(),
        descricao: descricaoController.text.trim(),
        concluida: false,
        idMateria: widget.materia.id!,
      );

      await tarefaService.inserirTarefa(tarefa);

      if (!mounted) return;

      tituloController.clear();
      descricaoController.clear();

      await carregarTarefas();

      Navigator.pop(context);
      _mostrarSucesso('Tarefa adicionada com sucesso!');
    } catch (e) {
      if (!mounted) return;
      _mostrarErro('Erro ao adicionar tarefa: ${e.toString()}');
    }
  }

  Future<void> atualizarStatusTarefa(int index, bool? newValue) async {
    if (newValue == null) return;

    try {
      tarefas[index].concluida = newValue;
      await tarefaService.atualizarTarefa(tarefas[index]);

      if (!mounted) return;

      await carregarTarefas();
      _mostrarSucesso(
        newValue
            ? 'Tarefa marcada como concluída!'
            : 'Tarefa marcada como pendente!',
      );
    } catch (e) {
      if (!mounted) return;

      // Reverter a mudança em caso de erro
      setState(() {
        tarefas[index].concluida = !newValue;
      });
      _mostrarErro('Erro ao atualizar tarefa: ${e.toString()}');
    }
  }

  Future<void> deletarTarefa(int index) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: Text(
            'Tem certeza que deseja deletar a tarefa "${tarefas[index].titulo}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deletar'),
            ),
          ],
        );
      },
    );

    if (confirmado == true) {
      try {
        await tarefaService.removerTarefa(tarefas[index].id!);

        if (!mounted) return;

        await carregarTarefas();
        _mostrarSucesso('Tarefa removida com sucesso!');
      } catch (e) {
        if (!mounted) return;
        _mostrarErro('Erro ao remover tarefa: ${e.toString()}');
      }
    }
  }

  void abrirDialogAdicionar() {
    tituloController.clear();
    descricaoController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova Tarefa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descricaoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: adicionarTarefa,
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.materia.nome)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: widget.materia.cor,
                  child: const Icon(Icons.menu_book, color: Colors.white),
                ),
                title: Text(widget.materia.nome),
                subtitle: Text(widget.materia.professor),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: carregarTarefas,
                            child: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : tarefas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.task_alt_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma tarefa cadastrada',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clique no + para adicionar uma nova',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: tarefas.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            tarefas[index].titulo,
                            style: TextStyle(
                              decoration: tarefas[index].concluida
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: tarefas[index].descricao.isNotEmpty
                              ? Text(tarefas[index].descricao)
                              : null,
                          value: tarefas[index].concluida,
                          onChanged: (value) {
                            atualizarStatusTarefa(index, value);
                          },
                          secondary: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              deletarTarefa(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: abrirDialogAdicionar,
        child: const Icon(Icons.add),
      ),
    );
  }
}
