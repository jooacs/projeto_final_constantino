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
  
  // Lista de ícones disponíveis
  final List<IconData> _iconesDisponiveis = [
    Icons.menu_book,
    Icons.science,
    Icons.calculate,
    Icons.history_edu,
    Icons.language,
    Icons.computer,
    Icons.biotech,
    Icons.brush,
    Icons.public,
    Icons.music_note,
    Icons.sports_basketball,
    Icons.psychology,
  ];

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

  // Helper function to build the dialog content
  Widget _buildDialogContent({
    required TextEditingController nomeController,
    required TextEditingController professorController,
    required IconData? selectedIcon,
    required void Function(IconData) onIconSelected,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nomeController,
          decoration: const InputDecoration(
            labelText: 'Nome da matéria',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: professorController,
          decoration: const InputDecoration(
            labelText: 'Professor',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Selecione um ícone:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _iconesDisponiveis.length,
            itemBuilder: (context, index) {
              final icon = _iconesDisponiveis[index];
              final isSelected = icon == selectedIcon;
              return InkWell(
                onTap: () => onIconSelected(icon),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : null,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // CREATE
  Future<void> adicionarMateria(IconData? selectedIcon) async {
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
        icone: selectedIcon ?? Icons.menu_book,
      );

      await materiaService.inserirMateria(materia);

      if (!mounted) return;

      await carregarMaterias();
      
      if (!mounted) return;
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
    IconData? currentIcon = materias[index].icone ?? Icons.menu_book;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Matéria'),
              content: _buildDialogContent(
                nomeController: nomeController,
                professorController: professorController,
                selectedIcon: currentIcon,
                onIconSelected: (icon) {
                  setState(() {
                    currentIcon = icon;
                  });
                },
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
                      materias[index].icone = currentIcon;

                      await materiaService.atualizarMateria(materias[index]);

                      if (!mounted) return;

                      await carregarMaterias();

                      if (!mounted) return;
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
          }
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
    IconData? currentIcon = Icons.menu_book;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nova Matéria'),
              content: _buildDialogContent(
                nomeController: nomeController,
                professorController: professorController,
                selectedIcon: currentIcon,
                onIconSelected: (icon) {
                  setState(() {
                    currentIcon = icon;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => adicionarMateria(currentIcon),
                  child: const Text('Adicionar'),
                ),
              ],
            );
          }
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
              padding: const EdgeInsets.all(12),
              itemCount: materias.length,
              itemBuilder: (context, index) {
                final materia = materias[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TelaDetalhesMateria(materia: materia),
                        ),
                      );
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: materia.cor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        materia.icone ?? Icons.menu_book, 
                        color: materia.cor,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      materia.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            materia.professor,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          color: Theme.of(context).primaryColor,
                          onPressed: () {
                            editarMateria(index);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirDialogAdicionar,
        icon: const Icon(Icons.add),
        label: const Text('Nova Matéria'),
      ),
    );
  }
}
