import 'package:flutter/material.dart';

import '../models/materias.dart';
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

  @override
  void initState() {
    super.initState();
    carregarTarefas();
  }

  Future<void> carregarTarefas() async {
    final lista = await tarefaService.buscarPorMateria(widget.materia.id!);

    setState(() {
      tarefas = lista;
    });
  }

  Future<void> adicionarTarefa() async {
    if (tituloController.text.isEmpty) {
      return;
    }

    final tarefa = Tarefa(
      titulo: tituloController.text,
      descricao: descricaoController.text,
      concluida: false,
      idMateria: widget.materia.id!,
    );

    await tarefaService.inserirTarefa(tarefa);

    tituloController.clear();
    descricaoController.clear();

    await carregarTarefas();

    Navigator.pop(context);
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
                decoration: const InputDecoration(labelText: 'Descrição'),
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
                title: Text(widget.materia.nome),
                subtitle: Text(widget.materia.professor),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: tarefas.length,
              itemBuilder: (context, index) {
                return CheckboxListTile(
                  title: Text(tarefas[index].titulo),
                  subtitle: Text(tarefas[index].descricao),
                  value: tarefas[index].concluida,
                  onChanged: (value) async {
                    tarefas[index].concluida = value!;

                    await tarefaService.atualizarTarefa(tarefas[index]);

                    await carregarTarefas();
                  },
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
