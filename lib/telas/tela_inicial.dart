import 'package:flutter/material.dart';
import 'tela_materias.dart';
import 'tela_resumo_pdf.dart';
import 'tela_tarefas.dart';
import 'tela_provas.dart';
import 'tela_cronograma.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> modules = [
      {
        'title': 'Matérias',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF3B82F6), // Blue
        'screen': const TelaMaterias(),
      },
      {
        'title': 'Notas',
        'icon': Icons.star_rounded,
        'color': const Color(0xFFF59E0B), // Amber
        'screen': null,
      },
      {
        'title': 'Tarefas',
        'icon': Icons.task_alt_rounded,
        'color': const Color(0xFF10B981), // Emerald
        'screen': const TelaTarefas(),
      },
      {
        'title': 'Provas',
        'icon': Icons.assignment_late_rounded,
        'color': const Color(0xFFEF4444), // Red
        'screen': const TelaProvas(),
      },
      {
        'title': 'Resumos IA',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF8B5CF6), // Violet
        'screen': const TelaResumoPdf(),
      },
      {
        'title': 'Metas',
        'icon': Icons.flag_rounded,
        'color': const Color(0xFF14B8A6), // Teal
        'screen': null,
      },
      {
        'title': 'Cronograma',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFF6366F1), // Indigo
        'screen': const TelaCronograma(),
      },
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Meu Painel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O que vamos estudar hoje?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    return _buildDashboardCard(context, module, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    Map<String, dynamic> module,
    int index,
  ) {
    final bool isImplemented = module['screen'] != null;
    final Color cardColor = module['color'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (isImplemented) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => module['screen']),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Text('${module['title']} em desenvolvimento'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        module['icon'],
                        size: 32,
                        color: cardColor,
                      ),
                    ),
                    Text(
                      module['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isImplemented)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Em breve',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
