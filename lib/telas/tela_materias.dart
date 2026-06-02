import 'package:flutter/material.dart';
import '../models/materias.dart';
import '../services/materia_service.dart';
import 'tela_detalhes_materia.dart';

class TelaMaterias extends StatefulWidget {
  const TelaMaterias({super.key});

  @override
  State<TelaMaterias> createState() => _TelaMateriasState();
}

class _TelaMateriasState extends State<TelaMaterias> {
  // Controllers
  final nomeController = TextEditingController();
  final professorController = TextEditingController();

  // Lista de matérias
  List<Materia> materias = [];

  final MateriaService materiaService = MateriaService();

  @override
  void initState() {
    super.initState();
    carregarMaterias();
  }

  Future<void> carregarMaterias() async {
    final lista = await materiaService.buscarMaterias();

    setState(() {
      materias = lista;
    });
  }

  // CREATE
  void adicionarMateria() async {
    if (nomeController.text.isEmpty || professorController.text.isEmpty) {
      return;
    }

    final materia = Materia(
      nome: nomeController.text,
      professor: professorController.text,
      cor: Colors.blue,
    );

    await materiaService.inserirMateria(materia);

    await carregarMaterias();

    nomeController.clear();
    professorController.clear();

    Navigator.pop(context);
  }

  // UPDATE
  void editarMateria(int index) {
    nomeController.text = materias[index].nome;

    professorController.text = materias[index].professor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Matéria'),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome da matéria'),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: professorController,
                decoration: const InputDecoration(labelText: 'Professor'),
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
              onPressed: () async {
                materias[index].nome = nomeController.text;

                materias[index].professor = professorController.text;

                await materiaService.atualizarMateria(materias[index]);

                await carregarMaterias();

                nomeController.clear();

                professorController.clear();

                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  // DELETE
  void removerMateria(int index) async {
    await materiaService.removerMateria(materias[index].id!);

    await carregarMaterias();
  }

  // Dialog CREATE
  void abrirDialogAdicionar() {
    nomeController.clear();
    professorController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nova Matéria'),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome da matéria'),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: professorController,
                decoration: const InputDecoration(labelText: 'Professor'),
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
              onPressed: adicionarMateria,
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matérias')),

      body: ListView.builder(
        itemCount: materias.length,

        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(10),

            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TelaDetalhesMateria(materia: materias[index]),
                  ),
                );
              },

              leading: CircleAvatar(
                backgroundColor: materias[index].cor,
                child: const Icon(Icons.menu_book, color: Colors.white),
              ),

              title: Text(materias[index].nome),

              subtitle: Text(materias[index].professor),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      editarMateria(index);
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      removerMateria(index);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: abrirDialogAdicionar,
        child: const Icon(Icons.add),
      ),
    );
  }
}
