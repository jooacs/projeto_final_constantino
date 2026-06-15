import 'dart:math';
import 'package:flutter/material.dart';
import '../models/nota.dart';
import '../models/materia.dart';
import '../services/nota_service.dart';
import '../services/materia_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno de desempenho por matéria
// ─────────────────────────────────────────────────────────────────────────────

class _Desempenho {
  final Materia materia;
  final List<Nota> notas;

  _Desempenho({required this.materia, required this.notas});

  bool get temNotas => notas.isNotEmpty;

  double get mediaPonderada {
    if (notas.isEmpty) return 0;
    final totalPeso = notas.fold(0.0, (s, n) => s + n.peso);
    if (totalPeso == 0) return 0;
    return notas.fold(0.0, (s, n) => s + n.valor * n.peso) / totalPeso;
  }

  List<Nota> get notasOrdenadas {
    final sorted = List<Nota>.from(notas);
    sorted.sort((a, b) {
      if (a.data == null && b.data == null) return 0;
      if (a.data == null) return 1;
      if (b.data == null) return -1;
      return a.data!.compareTo(b.data!);
    });
    return sorted;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela Principal
// ─────────────────────────────────────────────────────────────────────────────

class TelaNotas extends StatefulWidget {
  const TelaNotas({super.key});

  @override
  State<TelaNotas> createState() => _TelaNotasState();
}

class _TelaNotasState extends State<TelaNotas>
    with SingleTickerProviderStateMixin {
  final _notaService = NotaService();
  final _materiaService = MateriaService();
  late TabController _tabController;

  List<_Desempenho> _desempenhos = [];
  bool _isLoading = true;

  // Simulador
  final _mediaDesejadaCtrl = TextEditingController(text: '7.0');
  final _notasCtrl = TextEditingController();
  final _pesosCtrl = TextEditingController();
  final _proxAvalCtrl = TextEditingController();
  String? _resultadoSim;
  double? _notaNecessaria;
  bool _simCalculado = false;

  static const double _mediaMinPadrao = 7.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mediaDesejadaCtrl.dispose();
    _notasCtrl.dispose();
    _pesosCtrl.dispose();
    _proxAvalCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento ─────────────────────────────────────────────────────────

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    try {
      final materias = await _materiaService.buscarMaterias();
      final todasNotas = await _notaService.buscarTodas();

      final desempenhos = materias.map((m) {
        final notas = todasNotas.where((n) => n.idMateria == m.id).toList();
        return _Desempenho(materia: m, notas: notas);
      }).toList();

      // Ordenar por média desc
      desempenhos.sort((a, b) => b.mediaPonderada.compareTo(a.mediaPonderada));

      if (!mounted) return;
      setState(() {
        _desempenhos = desempenhos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _mostrarErro('Erro ao carregar notas: $e');
    }
  }

  // ── Stats globais ────────────────────────────────────────────────────────

  double get _mediaGeral {
    final all = _desempenhos.expand((d) => d.notas).toList();
    if (all.isEmpty) return 0;
    final totalPeso = all.fold(0.0, (s, n) => s + n.peso);
    if (totalPeso == 0) return 0;
    return all.fold(0.0, (s, n) => s + n.valor * n.peso) / totalPeso;
  }

  _Desempenho? get _melhorMateria {
    final com = _desempenhos.where((d) => d.temNotas).toList();
    if (com.isEmpty) return null;
    return com.reduce((a, b) => a.mediaPonderada >= b.mediaPonderada ? a : b);
  }

  _Desempenho? get _piorMateria {
    final com = _desempenhos.where((d) => d.temNotas).toList();
    if (com.isEmpty) return null;
    return com.reduce((a, b) => a.mediaPonderada <= b.mediaPonderada ? a : b);
  }

  int get _totalNotas => _desempenhos.fold(0, (s, d) => s + d.notas.length);

  List<_Desempenho> get _materiasEmRisco => _desempenhos
      .where((d) => d.temNotas && d.mediaPonderada < _mediaMinPadrao)
      .toList();

  // ── Helpers visuais ──────────────────────────────────────────────────────

  Color _corNota(double nota) {
    if (nota >= 9.0) return const Color(0xFF10B981);
    if (nota >= 7.0) return const Color(0xFF3B82F6);
    if (nota >= 5.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _labelNota(double nota) {
    if (nota >= 9.0) return 'Excelente';
    if (nota >= 7.0) return 'Bom';
    if (nota >= 5.0) return 'Regular';
    return 'Crítico';
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  void _mostrarSucesso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notas & Desempenho'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _carregar,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Visão Geral'),
            Tab(icon: Icon(Icons.calculate_rounded, size: 18), text: 'Simulador'),
            Tab(icon: Icon(Icons.emoji_events_rounded, size: 18), text: 'Ranking'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVisaoGeral(),
                _buildSimulador(),
                _buildRanking(),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 1 – VISÃO GERAL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildVisaoGeral() {
    final media = _mediaGeral;
    final melhor = _melhorMateria;
    final pior = _piorMateria;
    final emRisco = _materiasEmRisco;
    final comNotas = _desempenhos.where((d) => d.temNotas).toList();

    return RefreshIndicator(
      onRefresh: _carregar,
      color: const Color(0xFF4F46E5),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Hero: Média Geral
          _buildHeroCard(media),
          const SizedBox(height: 16),

          // Grid de stats 2×2
          Row(children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.assignment_turned_in_rounded,
                label: 'Avaliações',
                value: '$_totalNotas',
                cor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.school_rounded,
                label: 'Matérias',
                value: '${comNotas.length}',
                cor: const Color(0xFF4F46E5),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.trending_up_rounded,
                label: 'Melhor matéria',
                value: melhor != null
                    ? melhor.mediaPonderada.toStringAsFixed(1)
                    : '—',
                subtitulo: melhor?.materia.nome,
                cor: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.trending_down_rounded,
                label: 'Menor média',
                value: pior != null
                    ? pior.mediaPonderada.toStringAsFixed(1)
                    : '—',
                subtitulo: pior?.materia.nome,
                cor: const Color(0xFFF59E0B),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Desempenho por matéria
          _buildSecaoTitulo('📊 Evolução por Matéria'),
          const SizedBox(height: 12),
          if (comNotas.isEmpty)
            _buildVazio(
              'Nenhuma nota cadastrada',
              'Adicione notas às suas matérias para ver a evolução.',
            )
          else
            ...comNotas.map((d) => _buildCardMateria(d)),

          const SizedBox(height: 24),

          // Matérias em risco
          if (emRisco.isNotEmpty) ...[
            _buildSecaoTitulo('⚠️ Matérias em Risco'),
            const SizedBox(height: 4),
            Text(
              'Abaixo da média mínima de ${_mediaMinPadrao.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            ...emRisco.map((d) => _buildCardRisco(d)),
          ],

          // Botão Adicionar Nota
          const SizedBox(height: 8),
          _buildBotaoAdicionarNota(),
        ],
      ),
    );
  }

  Widget _buildHeroCard(double media) {
    final cor = _corNota(media == 0 ? 0 : media);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'MÉDIA GERAL',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            media == 0 ? '—' : media.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 62,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          if (media > 0) ...[
            Text(
              _labelNota(media),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (media / 10).clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  media >= 7 ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('0', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text(
                  'Meta: 7.0',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                ),
                const Text('10', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ] else
            Text(
              'Adicione notas para ver seu desempenho',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? subtitulo,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: cor)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          if (subtitulo != null)
            Text(subtitulo,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildCardMateria(_Desempenho d) {
    final media = d.mediaPonderada;
    final cor = _corNota(media);
    final notasOrd = d.notasOrdenadas;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirDetalhesMateria(d),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: d.materia.cor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.materia.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      media.toStringAsFixed(1),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: cor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (media / 10).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(cor),
                ),
              ),
              const SizedBox(height: 10),
              // Chips de cada nota
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: notasOrd
                    .map((n) => _buildChipNota(n))
                    .toList(),
              ),
              // Mini gráfico de evolução se tiver mais de 1 nota
              if (notasOrd.length >= 2) ...[
                const SizedBox(height: 10),
                _buildMiniGrafico(notasOrd),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipNota(Nota n) {
    final cor = _corNota(n.valor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${n.descricao}: ${n.valor.toStringAsFixed(1)}',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: cor),
      ),
    );
  }

  Widget _buildMiniGrafico(List<Nota> notas) {
    return SizedBox(
      height: 48,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final vals = notas.map((n) => n.valor).toList();
        final minV = vals.reduce(min);
        final maxV = vals.reduce(max);
        final range = (maxV - minV).clamp(0.5, 10.0);
        final step = vals.length > 1 ? w / (vals.length - 1) : w / 2;

        return CustomPaint(
          size: Size(w, 40),
          painter: _GraficoPainter(vals, minV, range, 40),
          child: Stack(
            children: List.generate(vals.length, (i) {
              final x = vals.length == 1 ? w / 2 : i * step;
              final y = 40 - ((vals[i] - minV) / range * 30) - 4;
              return Positioned(
                left: x - 12,
                top: y + 4,
                child: Text(
                  vals[i].toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: _corNota(vals[i])),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildCardRisco(_Desempenho d) {
    final media = d.mediaPonderada;
    // Nota mínima para recuperar a média numa próxima avaliação (peso 1)
    final somaAtual = d.notas.fold(0.0, (s, n) => s + n.valor * n.peso);
    final pesoAtual = d.notas.fold(0.0, (s, n) => s + n.peso);
    final notaNec =
        ((_mediaMinPadrao * (pesoAtual + 1)) - somaAtual).clamp(0, 10);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded,
                color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.materia.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF92400E))),
                Text('Média atual: ${media.toStringAsFixed(1)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB45309))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Precisa de',
                  style: TextStyle(fontSize: 10, color: Color(0xFFB45309))),
              Text(
                notaNec.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD97706)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoAdicionarNota() {
    return OutlinedButton.icon(
      onPressed: _abrirDialogAdicionarNota,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Adicionar Nota',
          style: TextStyle(fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4F46E5),
        side: const BorderSide(color: Color(0xFF4F46E5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 2 – SIMULADOR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSimulador() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Text('🎯', style: TextStyle(fontSize: 32)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simulador de Aprovação',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      SizedBox(height: 2),
                      Text(
                          'Calcule a nota que precisa tirar para passar.',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Campos
          _buildCampoSim(
            icone: Icons.flag_rounded,
            cor: const Color(0xFF4F46E5),
            label: 'Média mínima para aprovação',
            hint: 'Ex: 7.0',
            ctrl: _mediaDesejadaCtrl,
            teclado: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          _buildCampoSim(
            icone: Icons.grade_rounded,
            cor: const Color(0xFF10B981),
            label: 'Notas já obtidas (separadas por vírgula)',
            hint: 'Ex: 6.5, 8.0',
            ctrl: _notasCtrl,
            teclado: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          _buildCampoSim(
            icone: Icons.balance_rounded,
            cor: const Color(0xFFF59E0B),
            label: 'Pesos das avaliações (opcional)',
            hint: 'Ex: 1, 1, 1  — incluindo o peso da próxima',
            ctrl: _pesosCtrl,
            teclado: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          _buildCampoSim(
            icone: Icons.assignment_rounded,
            cor: const Color(0xFFEF4444),
            label: 'Nome da próxima avaliação (opcional)',
            hint: 'Ex: P3, Prova Final...',
            ctrl: _proxAvalCtrl,
          ),
          const SizedBox(height: 20),

          // Botão calcular
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calcularSimulador,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Calcular',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // Resultado
          if (_simCalculado && _resultadoSim != null) ...[
            const SizedBox(height: 16),
            _buildResultadoSim(),
          ],

          const SizedBox(height: 24),

          // Dica
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡 Como usar',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3730A3),
                        fontSize: 13)),
                SizedBox(height: 6),
                Text(
                  '• Informe a média que precisa atingir\n'
                  '• Liste suas notas já obtidas separadas por vírgula\n'
                  '• Se as provas têm pesos diferentes, informe-os\n'
                  '• O último peso corresponde à próxima avaliação',
                  style: TextStyle(
                      color: Color(0xFF4338CA), fontSize: 12, height: 1.7),
                ),
              ],
            ),
          ),

          // Simulação com notas cadastradas
          if (_desempenhos.any((d) => d.temNotas)) ...[
            const SizedBox(height: 24),
            _buildSimuladoresRapidos(),
          ],
        ],
      ),
    );
  }

  Widget _buildCampoSim({
    required IconData icone,
    required Color cor,
    required String label,
    required String hint,
    required TextEditingController ctrl,
    TextInputType? teclado,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                TextField(
                  controller: ctrl,
                  keyboardType: teclado,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                        fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoSim() {
    final notaNec = _notaNecessaria;
    final String emoji;
    final Color cor;
    final Color corFundo;
    final Color corBorda;

    if (notaNec == null) {
      emoji = '❓';
      cor = const Color(0xFF64748B);
      corFundo = const Color(0xFFF8FAFC);
      corBorda = const Color(0xFFE2E8F0);
    } else if (notaNec <= 0) {
      emoji = '🎉';
      cor = const Color(0xFF065F46);
      corFundo = const Color(0xFFF0FDF4);
      corBorda = const Color(0xFF34D399);
    } else if (notaNec > 10) {
      emoji = '😔';
      cor = const Color(0xFF7F1D1D);
      corFundo = const Color(0xFFFEF2F2);
      corBorda = const Color(0xFFFCA5A5);
    } else {
      emoji = '🎯';
      cor = const Color(0xFF1E3A5F);
      corFundo = const Color(0xFFEFF6FF);
      corBorda = const Color(0xFF93C5FD);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: corBorda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _resultadoSim!,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cor,
                      height: 1.4),
                ),
                if (notaNec != null && notaNec > 0 && notaNec <= 10) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (notaNec / 10).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: corBorda.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(corBorda),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notaNec.toStringAsFixed(1)} / 10',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cor.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimuladoresRapidos() {
    final comNotas = _desempenhos.where((d) => d.temNotas).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSecaoTitulo('⚡ Simulação rápida por matéria'),
        const SizedBox(height: 4),
        const Text(
          'Quanto precisa tirar na próxima avaliação (peso 1)',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 12),
        ...comNotas.map((d) {
          final somaAtual =
              d.notas.fold(0.0, (s, n) => s + n.valor * n.peso);
          final pesoAtual =
              d.notas.fold(0.0, (s, n) => s + n.peso);
          const mediaAlvo = 7.0;
          final notaNec =
              ((mediaAlvo * (pesoAtual + 1)) - somaAtual).clamp(0, 10);
          final cor = _corNota(d.mediaPonderada);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: d.materia.cor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.materia.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1E293B))),
                      Text(
                          'Média atual: ${d.mediaPonderada.toStringAsFixed(1)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      notaNec <= 0
                          ? '✅'
                          : notaNec.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: notaNec <= 0
                              ? const Color(0xFF10B981)
                              : cor),
                    ),
                    if (notaNec > 0)
                      const Text('necessário',
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _calcularSimulador() {
    try {
      final mediaAlvo = double.tryParse(
              _mediaDesejadaCtrl.text.trim().replaceAll(',', '.')) ??
          0;

      if (_notasCtrl.text.trim().isEmpty) {
        setState(() {
          _simCalculado = true;
          _notaNecessaria = null;
          _resultadoSim = 'Informe pelo menos uma nota já obtida.';
        });
        return;
      }

      final notas = _notasCtrl.text
          .split(',')
          .map((s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0.0)
          .toList();

      List<double> pesos;
      if (_pesosCtrl.text.trim().isEmpty) {
        pesos = List.filled(notas.length + 1, 1.0);
      } else {
        pesos = _pesosCtrl.text
            .split(',')
            .map((s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 1.0)
            .toList();
        while (pesos.length < notas.length + 1) {
          pesos.add(1.0);
        }
      }

      final totalPesos = pesos.reduce((a, b) => a + b);
      double somaAtual = 0;
      for (int i = 0; i < notas.length; i++) {
        somaAtual += notas[i] * pesos[i];
      }

      final pesoProxima = pesos[notas.length];
      final notaNec =
          (mediaAlvo * totalPesos - somaAtual) / pesoProxima;

      final nomeSeg = _proxAvalCtrl.text.trim().isEmpty
          ? 'próxima avaliação'
          : _proxAvalCtrl.text.trim();

      String resultado;
      if (notaNec <= 0) {
        resultado =
            'Você já atingiu a média! Sua média atual supera ${mediaAlvo.toStringAsFixed(1)}.';
      } else if (notaNec > 10) {
        resultado =
            'Não é mais possível atingir ${mediaAlvo.toStringAsFixed(1)} com as notas informadas, mesmo tirando 10 na $nomeSeg.';
      } else {
        resultado =
            'Você precisa tirar ${notaNec.toStringAsFixed(1)} na $nomeSeg para atingir a média ${mediaAlvo.toStringAsFixed(1)}.';
      }

      setState(() {
        _simCalculado = true;
        _notaNecessaria = notaNec;
        _resultadoSim = resultado;
      });
    } catch (_) {
      setState(() {
        _simCalculado = true;
        _notaNecessaria = null;
        _resultadoSim = 'Verifique os valores informados e tente novamente.';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA 3 – RANKING
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRanking() {
    final comNotas = _desempenhos.where((d) => d.temNotas).toList();
    // Já ordenado por média desc

    if (comNotas.isEmpty) {
      return Center(
        child: _buildVazio(
          'Nenhuma nota cadastrada ainda.',
          'Adicione notas às matérias para ver o ranking.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: comNotas.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildCabecalhoRanking();
        return _buildItemRanking(comNotas[index - 1], index - 1);
      },
    );
  }

  Widget _buildCabecalhoRanking() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Text('🏆', style: TextStyle(fontSize: 32)),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ranking Pessoal',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              Text('Matérias ordenadas por desempenho',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRanking(_Desempenho d, int index) {
    final media = d.mediaPonderada;
    final cor = _corNota(media);
    final isTop3 = index < 3;
    final medalhas = ['🥇', '🥈', '🥉'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTop3 ? cor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3
              ? cor.withValues(alpha: 0.25)
              : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Center(
              child: isTop3
                  ? Text(medalhas[index],
                      style: const TextStyle(fontSize: 22))
                  : Text('${index + 1}º',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8))),
            ),
          ),
          const SizedBox(width: 8),
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: d.materia.cor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.materia.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B))),
                Text(
                  '${d.materia.professor} • ${d.notas.length} avaliação${d.notas.length != 1 ? 'ões' : ''}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                media.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: cor),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (media / 10).clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(cor),
                  ),
                ),
              ),
              Text(
                _labelNota(media),
                style: TextStyle(fontSize: 9, color: cor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────────────────────────────────────

  void _abrirDialogAdicionarNota() {
    if (_desempenhos.isEmpty) {
      _mostrarErro('Cadastre pelo menos uma matéria primeiro.');
      return;
    }

    final descricaoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final pesoCtrl = TextEditingController(text: '1.0');
    _Desempenho? materiaSel = _desempenhos.first;
    String tipoSel = 'prova';
    DateTime? dataSel = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Nova Nota',
              style: TextStyle(fontWeight: FontWeight.w800)),
          contentPadding:
              const EdgeInsets.fromLTRB(20, 16, 20, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Matéria
                const Text('Matéria',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                DropdownButtonFormField<_Desempenho>(
                  value: materiaSel,
                  items: _desempenhos
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.materia.nome,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setDs(() => materiaSel = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Descrição
                TextField(
                  controller: descricaoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (ex: P1, Trabalho)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Valor e Peso lado a lado
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Nota (0-10)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Peso',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Tipo
                const Text('Tipo de avaliação',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: tipoSel,
                  items: const [
                    DropdownMenuItem(value: 'prova', child: Text('Prova')),
                    DropdownMenuItem(
                        value: 'trabalho', child: Text('Trabalho')),
                    DropdownMenuItem(
                        value: 'participacao',
                        child: Text('Participação')),
                    DropdownMenuItem(value: 'outro', child: Text('Outro')),
                  ],
                  onChanged: (v) => setDs(() => tipoSel = v ?? 'prova'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Data
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Data da avaliação',
                      style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                    dataSel != null
                        ? '${dataSel!.day.toString().padLeft(2, '0')}/${dataSel!.month.toString().padLeft(2, '0')}/${dataSel!.year}'
                        : 'Toque para selecionar',
                    style: const TextStyle(color: Color(0xFF4F46E5)),
                  ),
                  trailing: const Icon(Icons.calendar_today_rounded,
                      size: 18, color: Color(0xFF4F46E5)),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: dataSel ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setDs(() => dataSel = p);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (descricaoCtrl.text.trim().isEmpty) {
                  _mostrarErro('Informe a descrição.');
                  return;
                }
                final valor = double.tryParse(
                    valorCtrl.text.trim().replaceAll(',', '.'));
                if (valor == null || valor < 0 || valor > 10) {
                  _mostrarErro('Nota deve ser entre 0 e 10.');
                  return;
                }
                final peso = double.tryParse(
                        pesoCtrl.text.trim().replaceAll(',', '.')) ??
                    1.0;
                if (materiaSel == null) return;

                final nota = Nota(
                  idMateria: materiaSel!.materia.id!,
                  descricao: descricaoCtrl.text.trim(),
                  valor: valor,
                  peso: peso,
                  tipo: tipoSel,
                  data: dataSel,
                );

                try {
                  await _notaService.inserirNota(nota);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _mostrarSucesso('Nota adicionada!');
                  _carregar();
                } catch (e) {
                  _mostrarErro('Erro: $e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDetalhesMateria(_Desempenho d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DetalhesMateriaNota(
        desempenho: d,
        notaService: _notaService,
        onAtualizar: _carregar,
      ),
    );
  }

  // ── Widgets de suporte ───────────────────────────────────────────────────

  Widget _buildSecaoTitulo(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1E293B)),
    );
  }

  Widget _buildVazio(String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.bar_chart_rounded,
              size: 56, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          Text(titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(subtitulo,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de detalhes / edição por matéria
// ─────────────────────────────────────────────────────────────────────────────

class _DetalhesMateriaNota extends StatefulWidget {
  final _Desempenho desempenho;
  final NotaService notaService;
  final VoidCallback onAtualizar;

  const _DetalhesMateriaNota({
    required this.desempenho,
    required this.notaService,
    required this.onAtualizar,
  });

  @override
  State<_DetalhesMateriaNota> createState() => _DetalhesMateriaNotaState();
}

class _DetalhesMateriaNotaState extends State<_DetalhesMateriaNota> {
  Color _corNota(double nota) {
    if (nota >= 9.0) return const Color(0xFF10B981);
    if (nota >= 7.0) return const Color(0xFF3B82F6);
    if (nota >= 5.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _formatData(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _excluirNota(Nota nota) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir nota?'),
        content: Text('Excluir "${nota.descricao}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.notaService.removerNota(nota.id!);
      widget.onAtualizar();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.desempenho;
    final media = d.mediaPonderada;
    final cor = _corNota(media);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: d.materia.cor,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(d.materia.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Color(0xFF1E293B))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Média: ${media.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: cor),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: d.notas.isEmpty
                  ? const Center(
                      child: Text('Nenhuma nota cadastrada.',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.all(20),
                      itemCount: d.notasOrdenadas.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final nota = d.notasOrdenadas[i];
                        final c = _corNota(nota.valor);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFF1F5F9)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    nota.valor.toStringAsFixed(1),
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.w900,
                                        fontSize: 14,
                                        color: c),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(nota.descricao,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 14,
                                            color:
                                                Color(0xFF1E293B))),
                                    Text(
                                      '${nota.tipo} • Peso: ${nota.peso.toStringAsFixed(1)} • ${_formatData(nota.data)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 20),
                                onPressed: () => _excluirNota(nota),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter do mini-gráfico de evolução
// ─────────────────────────────────────────────────────────────────────────────

class _GraficoPainter extends CustomPainter {
  final List<double> valores;
  final double minV;
  final double range;
  final double altura;

  _GraficoPainter(this.valores, this.minV, this.range, this.altura);

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF4F46E5).withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final step = size.width / (valores.length - 1);
    final path = Path();

    for (int i = 0; i < valores.length; i++) {
      final x = i * step;
      final y = altura - ((valores[i] - minV) / range * (altura - 10)) - 5;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GraficoPainter old) => valores != old.valores;
}