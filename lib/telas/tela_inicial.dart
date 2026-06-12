import 'package:flutter/material.dart';
import '../database/db_utils.dart';
import '../services/prova_service.dart';
import '../services/auth_service.dart';
import 'tela_materias.dart';
import 'tela_resumo_pdf.dart';
import 'tela_tarefas.dart';
import 'tela_provas.dart';
import 'tela_cronograma.dart';
import 'tela_login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingStats = true;
  int _totalMaterias = 0;
  int _tarefasPendentes = 0;
  int _tarefasConcluidas = 0;
  String? _proximaProva;

  final ProvaService _provaService = ProvaService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _carregarEstatisticas();
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              navigator.pop();
              await _authService.logout();
              if (!mounted) return;
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text(
              'Sair',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarEstatisticas() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);

    try {
      final stats = await DbUtils.getDatabaseStats();
      final todasProvas = await _provaService.buscarTodas();
      final agora = DateTime.now();
      final proximasProvas = todasProvas
          .where(
            (p) =>
                !p.realizada &&
                p.dataProva != null &&
                p.dataProva!.isAfter(agora),
          )
          .toList();
      proximasProvas.sort((a, b) => a.dataProva!.compareTo(b.dataProva!));

      String? textoProva;
      if (proximasProvas.isNotEmpty) {
        final prova = proximasProvas.first;
        final diff = prova.dataProva!.difference(agora).inDays;
        final dataFmt =
            '${prova.dataProva!.day.toString().padLeft(2, '0')}/${prova.dataProva!.month.toString().padLeft(2, '0')}';
        if (diff == 0) {
          textoProva = '${prova.titulo} — hoje!';
        } else if (diff == 1) {
          textoProva = '${prova.titulo} — amanhã ($dataFmt)';
        } else {
          textoProva = '${prova.titulo} — em $diff dias ($dataFmt)';
        }
      }

      if (!mounted) return;
      setState(() {
        _totalMaterias = (stats['total_materias'] as int?) ?? 0;
        _tarefasPendentes = (stats['tarefas_pendentes'] as int?) ?? 0;
        _tarefasConcluidas = (stats['tarefas_concluidas'] as int?) ?? 0;
        _proximaProva = textoProva;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
    }
  }

  List<Map<String, dynamic>> get _modules => [
    {
      'title': 'Matérias',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFF3B82F6),
      'screen': const TelaMaterias(),
    },
    {
      'title': 'Notas',
      'icon': Icons.star_rounded,
      'color': const Color(0xFFF59E0B),
      'screen': null,
    },
    {
      'title': 'Tarefas',
      'icon': Icons.task_alt_rounded,
      'color': const Color(0xFF10B981),
      'screen': const TelaTarefas(),
    },
    {
      'title': 'Provas',
      'icon': Icons.assignment_late_rounded,
      'color': const Color(0xFFEF4444),
      'screen': const TelaProvas(),
    },
    {
      'title': 'Resumos IA',
      'icon': Icons.auto_awesome_rounded,
      'color': const Color(0xFF8B5CF6),
      'screen': const TelaResumoPdf(),
    },
    {
      'title': 'Metas',
      'icon': Icons.flag_rounded,
      'color': const Color(0xFF14B8A6),
      'screen': null,
    },
    {
      'title': 'Cronograma',
      'icon': Icons.calendar_month_rounded,
      'color': const Color(0xFF6366F1),
      'screen': const TelaCronograma(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Painel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 24),
            onPressed: _carregarEstatisticas,
            tooltip: 'Atualizar',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    SizedBox(width: 12),
                    Text('Sair', style: TextStyle(color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
            child: IconButton(
              icon: const Icon(Icons.account_circle_rounded, size: 28),
              onPressed: null,
            ),
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregarEstatisticas,
          color: const Color(0xFF4F46E5),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'O que vamos estudar hoje?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatsBanner(),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildDashboardCard(context, _modules[index]),
                    childCount: _modules.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBanner() {
    if (_isLoadingStats) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4F46E5),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    final int totalTarefas = _tarefasPendentes + _tarefasConcluidas;
    final double progresso = totalTarefas > 0
        ? _tarefasConcluidas / totalTarefas
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatChip(
                icon: Icons.menu_book_rounded,
                label: 'Matérias',
                value: '$_totalMaterias',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.task_alt_rounded,
                label: 'Pendentes',
                value: '$_tarefasPendentes',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.check_circle_rounded,
                label: 'Concluídas',
                value: '$_tarefasConcluidas',
              ),
            ],
          ),
          if (totalTarefas > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progresso das tarefas',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progresso * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progresso,
                          minHeight: 7,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_proximaProva != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Próxima prova: $_proximaProva',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    Map<String, dynamic> module,
  ) {
    final bool isImplemented = module['screen'] != null;
    final Color cardColor = module['color'] as Color;
    final screen = module['screen'] as Widget?;

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
            if (isImplemented && screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => screen),
              ).then((_) => _carregarEstatisticas());
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
          child: Padding(
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
                    module['icon'] as IconData,
                    size: 32,
                    color: cardColor,
                  ),
                ),
                Text(
                  module['title'] as String,
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
        ),
      ),
    );
  }
}
