import 'package:flutter/material.dart';
import '../database/db_utils.dart';
import '../services/prova_service.dart';
import '../services/nota_service.dart';
import '../services/materia_service.dart';
import '../services/auth_service.dart';
import '../models/prova.dart';
import '../models/nota.dart';
import '../models/materia.dart';
import 'tela_materias.dart';
import 'tela_resumo_pdf.dart';
import 'tela_gerador_quiz.dart';
import 'tela_pomodoro.dart';
import 'tela_tarefas.dart';
import 'tela_provas.dart';
import 'tela_notas.dart';
import 'tela_cronograma.dart';
import 'tela_login.dart';
import 'tela_questoes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Serviços
  final _provaService = ProvaService();
  final _notaService = NotaService();
  final _materiaService = MateriaService();
  final _authService = AuthService();

  // Estado do dashboard
  bool _isLoading = true;
  int _totalMaterias = 0;
  int _totalTarefas = 0;
  int _tarefasPendentes = 0;
  int _tarefasConcluidas = 0;
  String? _proximaProva;
  double _mediaGeral = 0;
  String? _melhorMateria;
  String? _materiaEmRisco;
  double? _melhorMedia;
  double? _mediaRisco;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _carregar();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DbUtils.getDatabaseStats(),
        _provaService.buscarTodas(),
        _notaService.buscarTodas(),
        _materiaService.buscarMaterias(),
      ]);

      final stats = results[0] as Map<String, dynamic>;
      final provas = results[1] as List<Prova>;
      final notas = results[2] as List<Nota>;
      final materias = results[3] as List<Materia>;

      // Próxima prova
      final agora = DateTime.now();
      final proximas = provas
          .where((p) =>
              !p.realizada &&
              p.dataProva != null &&
              p.dataProva!.isAfter(agora))
          .toList()
        ..sort((a, b) => a.dataProva!.compareTo(b.dataProva!));

      String? textoProva;
      if (proximas.isNotEmpty) {
        final p = proximas.first;
        final diff = p.dataProva!.difference(agora).inDays;
        final dataFmt =
            '${p.dataProva!.day.toString().padLeft(2, '0')}/${p.dataProva!.month.toString().padLeft(2, '0')}';
        if (diff == 0) {
          textoProva = '${p.titulo} — HOJE!';
        } else if (diff == 1) {
          textoProva = '${p.titulo} — amanhã ($dataFmt)';
        } else {
          textoProva = '${p.titulo} — em $diff dias ($dataFmt)';
        }
      }

      // Média geral
      double mediaGeral = 0;
      if (notas.isNotEmpty) {
        final totalPeso = notas.fold(0.0, (s, n) => s + n.peso);
        if (totalPeso > 0) {
          mediaGeral = notas.fold(0.0, (s, n) => s + n.valor * n.peso) /
              totalPeso;
        }
      }

      // Melhor matéria e em risco (por notas)
      String? melhorNome;
      double? melhorM;
      String? riscoNome;
      double? riscoM;

      final mediasPorMateria = <int, List<Nota>>{};
      for (final n in notas) {
        mediasPorMateria.putIfAbsent(n.idMateria, () => []).add(n);
      }

      mediasPorMateria.forEach((idMat, ns) {
        final totalP = ns.fold(0.0, (s, n) => s + n.peso);
        if (totalP == 0) return;
        final med = ns.fold(0.0, (s, n) => s + n.valor * n.peso) / totalP;
        final nome = materias
            .firstWhere((m) => m.id == idMat,
                orElse: () => Materia(
                    nome: '?',
                    professor: '',
                    cor: Colors.grey))
            .nome;

        if (melhorM == null || med > melhorM!) {
          melhorM = med;
          melhorNome = nome;
        }
        if (riscoM == null || med < riscoM!) {
          riscoM = med;
          riscoNome = nome;
        }
      });

      if (!mounted) return;
      setState(() {
        _totalMaterias = (stats['total_materias'] as int?) ?? 0;
        _totalTarefas =
            ((stats['tarefas_pendentes'] as int?) ?? 0) +
                ((stats['tarefas_concluidas'] as int?) ?? 0);
        _tarefasPendentes = (stats['tarefas_pendentes'] as int?) ?? 0;
        _tarefasConcluidas = (stats['tarefas_concluidas'] as int?) ?? 0;
        _proximaProva = textoProva;
        _mediaGeral = mediaGeral;
        _melhorMateria = melhorNome;
        _melhorMedia = melhorM;
        _materiaEmRisco =
            (riscoM != null && riscoM! < 7.0) ? riscoNome : null;
        _mediaRisco = riscoM;
        _isLoading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final nav = Navigator.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar saída'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
              onPressed: () => nav.pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              nav.pop();
              await _authService.logout();
              if (!mounted) return;
              nav.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('Sair',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _modules => [
        {
          'title': 'Matérias',
          'icon': Icons.menu_book_rounded,
          'color': const Color(0xFF3B82F6),
          'screen': const TelaMaterias(),
          'ativo': true,
        },
        {
          'title': 'Notas',
          'icon': Icons.star_rounded,
          'color': const Color(0xFFF59E0B),
          'screen': const TelaNotas(),
          'ativo': true,
        },
        {
          'title': 'Tarefas',
          'icon': Icons.task_alt_rounded,
          'color': const Color(0xFF10B981),
          'screen': const TelaTarefas(),
          'ativo': true,
        },
        {
          'title': 'Provas',
          'icon': Icons.assignment_late_rounded,
          'color': const Color(0xFFEF4444),
          'screen': const TelaProvas(),
          'ativo': true,
        },
        {
          'title': 'IA Resumos',
          'icon': Icons.auto_awesome_rounded,
          'color': const Color(0xFF8B5CF6),
          'screen': const TelaResumoPdf(),
          'ativo': true,
        },
        {
          'title': 'IA Quiz',
          'icon': Icons.quiz_rounded,
          'color': const Color(0xFFEC4899),
          'screen': const TelaGeradorQuiz(),
          'ativo': true,
        },
        {
          'title': 'Questões de Anexos',
          'icon': Icons.contact_support_rounded,
          'color': const Color(0xFF10B981),
          'screen': const TelaQuestoes(),
          'ativo': true,
        },
        {
          'title': 'Metas',
          'icon': Icons.flag_rounded,
          'color': const Color(0xFF14B8A6),
          'screen': null,
          'ativo': false,
        },
        {
          'title': 'Cronograma',
          'icon': Icons.calendar_month_rounded,
          'color': const Color(0xFF6366F1),
          'screen': const TelaCronograma(),
          'ativo': true,
        },
        {
          'title': 'Pomodoro',
          'icon': Icons.timer_rounded,
          'color': const Color(0xFFE11D48),
          'screen': const TelaPomodoro(),
          'ativo': true,
        },
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Meu Painel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _carregar,
            tooltip: 'Atualizar',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _handleLogout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  SizedBox(width: 12),
                  Text('Sair', style: TextStyle(color: Color(0xFFEF4444))),
                ]),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.account_circle_rounded, size: 28),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carregar,
          color: const Color(0xFF4F46E5),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'O que vamos estudar hoje?',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? _buildLoadingBanner()
                        : FadeTransition(
                            opacity: _fadeAnim,
                            child: _buildDashboard(),
                          ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                        _buildModuleCard(context, _modules[i]),
                    childCount: _modules.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Widget _buildLoadingBanner() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF4F46E5), strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildDashboard() {
    final total = _tarefasPendentes + _tarefasConcluidas;
    final progresso = total > 0 ? _tarefasConcluidas / total : 0.0;

    return Column(
      children: [
        // Banner principal com gradiente
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4338CA), Color(0xFF6D28D9)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4338CA).withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Linha 1: matérias, tarefas, pendentes
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.menu_book_rounded,
                    label: 'Matérias',
                    value: '$_totalMaterias',
                  ),
                  const SizedBox(width: 10),
                  _buildStatChip(
                    icon: Icons.task_alt_rounded,
                    label: 'Pendentes',
                    value: '$_tarefasPendentes',
                  ),
                  const SizedBox(width: 10),
                  _buildStatChip(
                    icon: Icons.check_circle_rounded,
                    label: 'Feitas',
                    value: '$_tarefasConcluidas',
                  ),
                ],
              ),
              // Progresso de tarefas
              if (total > 0) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progresso das tarefas',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${(progresso * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progresso,
                    minHeight: 7,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white),
                  ),
                ),
              ],
              // Próxima prova
              if (_proximaProva != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📅 $_proximaProva',
                          style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.92),
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Segunda linha: média, melhor matéria, em risco
        if (_mediaGeral > 0 ||
            _melhorMateria != null ||
            _materiaEmRisco != null)
          Row(
            children: [
              // Média Geral
              Expanded(
                child: _buildMiniCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Média Geral',
                  value: _mediaGeral > 0
                      ? _mediaGeral.toStringAsFixed(1)
                      : '—',
                  cor: _mediaGeral >= 7
                      ? const Color(0xFF10B981)
                      : _mediaGeral > 0
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF94A3B8),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TelaNotas()),
                  ).then((_) => _carregar()),
                ),
              ),
              const SizedBox(width: 10),
              // Melhor matéria
              if (_melhorMateria != null)
                Expanded(
                  child: _buildMiniCard(
                    icon: Icons.emoji_events_rounded,
                    label: 'Melhor',
                    value: _melhorMedia?.toStringAsFixed(1) ?? '—',
                    subtitulo: _melhorMateria,
                    cor: const Color(0xFF3B82F6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TelaNotas()),
                    ).then((_) => _carregar()),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 10),
              // Em risco
              if (_materiaEmRisco != null)
                Expanded(
                  child: _buildMiniCard(
                    icon: Icons.warning_rounded,
                    label: 'Em risco',
                    value: _mediaRisco?.toStringAsFixed(1) ?? '—',
                    subtitulo: _materiaEmRisco,
                    cor: const Color(0xFFEF4444),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TelaNotas()),
                    ).then((_) => _carregar()),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 9,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required String label,
    required String value,
    String? subtitulo,
    required Color cor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cor, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: cor)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
            if (subtitulo != null)
              Text(subtitulo,
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Cards de módulos ─────────────────────────────────────────────────────

  Widget _buildModuleCard(BuildContext context, Map<String, dynamic> m) {
    final bool ativo = m['ativo'] as bool;
    final Color cor = m['color'] as Color;
    final Widget? screen = m['screen'] as Widget?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: cor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (ativo && screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => screen),
              ).then((_) => _carregar());
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                content: Text('${m['title']} em desenvolvimento'),
                duration: const Duration(seconds: 2),
              ));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(m['icon'] as IconData,
                          size: 28, color: cor),
                    ),
                    if (!ativo)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time_rounded,
                              size: 9, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                Text(
                  m['title'] as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ativo
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
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