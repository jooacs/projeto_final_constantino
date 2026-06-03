import 'package:flutter/material.dart';
import '../models/materia.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

  final MateriaService materiaService = MateriaService();

  @override
  void initState() {
    super.initState();
    carregarMaterias();
  }

  @override
  void dispose() {
    nomeController.dispose();
    professorController.dispose();
    super.dispose();
  }

  Future<void> carregarMaterias() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lista = await materiaService.buscarMaterias();

      if (!mounted) return;

      setState(() {
        materias = lista;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Erro ao carregar matérias: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // CREATE
  Future<void> adicionarMateria() async {
    if (nomeController.text.trim().isEmpty ||
        professorController.text.trim().isEmpty) {
      _mostrarErro('Preencha todos os campos');
      return;
    }

    try {
      final materia = Materia(
        nome: nomeController.text.trim(),
        professor: professorController.text.trim(),
        cor: Colors.blue,
      );

      await materiaService.inserirMateria(materia);

      if (!mounted) return;

      await carregarMaterias();
      nomeController.clear();
      professorController.clear();

      Navigator.pop(context);
      _mostrarSucesso('Matéria adicionada com sucesso!');
    } catch (e) {
      if (!mounted) return;
      _mostrarErro('Erro ao adicionar matéria: ${e.toString()}');
    }
  }

  // UPDATE
  Future<void> editarMateria(int index) async {
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
                if (nomeController.text.trim().isEmpty ||
                    professorController.text.trim().isEmpty) {
                  _mostrarErro('Preencha todos os campos');
                  return;
                }

                try {
                  materias[index].nome = nomeController.text.trim();
                  materias[index].professor = professorController.text.trim();

                  await materiaService.atualizarMateria(materias[index]);

                  if (!mounted) return;

                  await carregarMaterias();
                  nomeController.clear();
                  professorController.clear();

                  Navigator.pop(context);
                  _mostrarSucesso('Matéria atualizada com sucesso!');
                } catch (e) {
                  if (!mounted) return;
                  _mostrarErro('Erro ao atualizar: ${e.toString()}');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  // DELETE
  Future<void> removerMateria(int index) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: Text(
            'Tem certeza que deseja deletar "${materias[index].nome}"? '
            'Todas as tarefas associadas também serão removidas.',
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
        await materiaService.removerMateria(materias[index].id!);

        if (!mounted) return;

        await carregarMaterias();
        _mostrarSucesso('Matéria removida com sucesso!');
      } catch (e) {
        if (!mounted) return;
        _mostrarErro('Erro ao remover: ${e.toString()}');
      }
    }
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
      appBar: AppBar(title: const Text('Matérias')),
      body: _isLoading
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
                      onPressed: carregarMaterias,
                      child: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              ),
            )
          : materias.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma matéria cadastrada',
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
                          icon: const Icon(Icons.delete, color: Colors.red),
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
