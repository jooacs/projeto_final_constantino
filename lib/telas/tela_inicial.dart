import 'package:flutter/material.dart';
import 'tela_materias.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> modules = [
      {'title': 'Matérias', 'icon': Icons.menu_book, 'color': Colors.blue},
      {'title': 'Notas', 'icon': Icons.star, 'color': Colors.orange},
      {'title': 'Tarefas', 'icon': Icons.task_alt, 'color': Colors.green},
      {'title': 'Provas', 'icon': Icons.assignment_late, 'color': Colors.red},
      {'title': 'Resumos', 'icon': Icons.description, 'color': Colors.purple},
      {'title': 'Metas de Estudo', 'icon': Icons.flag, 'color': Colors.teal},
      {
        'title': 'Cronograma',
        'icon': Icons.calendar_month,
        'color': Colors.indigo,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meu Painel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return _buildDashboardCard(context, module);
          },
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    Map<String, dynamic> module,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (module['title'] == 'Matérias') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TelaMaterias()),
            );
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: module['color'].withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(module['icon'], size: 36, color: module['color']),
            ),
            const SizedBox(height: 12),
            Text(
              module['title'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
