import 'dart:async';
import 'package:flutter/material.dart';

class TelaPomodoro extends StatefulWidget {
  const TelaPomodoro({super.key});

  @override
  State<TelaPomodoro> createState() => _TelaPomodoroState();
}

class _TelaPomodoroState extends State<TelaPomodoro> {
  static const int _workDuration = 25 * 60;
  static const int _shortBreakDuration = 5 * 60;
  static const int _longBreakDuration = 15 * 60;

  int _timeLeft = _workDuration;
  bool _isRunning = false;
  Timer? _timer;
  String _currentMode = 'Foco'; // 'Foco', 'Pausa Curta', 'Pausa Longa'
  int _cycles = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer!.cancel();
          _isRunning = false;
          _onTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _setMode(_currentMode);
    });
  }

  void _onTimerComplete() {
    if (_currentMode == 'Foco') {
      _cycles++;
      if (_cycles % 4 == 0) {
        _setMode('Pausa Longa');
      } else {
        _setMode('Pausa Curta');
      }
    } else {
      _setMode('Foco');
    }
    
    // Mostra um aviso quando terminar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _currentMode == 'Foco' 
            ? 'Hora de focar! Vamos lá.' 
            : 'Tempo esgotado! Aproveite sua pausa.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _getModeColor(),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _setMode(String mode) {
    setState(() {
      _currentMode = mode;
      _isRunning = false;
      _timer?.cancel();
      if (mode == 'Foco') {
        _timeLeft = _workDuration;
      } else if (mode == 'Pausa Curta') {
        _timeLeft = _shortBreakDuration;
      } else if (mode == 'Pausa Longa') {
        _timeLeft = _longBreakDuration;
      }
    });
  }

  Color _getModeColor() {
    if (_currentMode == 'Foco') return const Color(0xFFEF4444); // Red
    if (_currentMode == 'Pausa Curta') return const Color(0xFF10B981); // Green
    return const Color(0xFF3B82F6); // Blue
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = _getModeColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Pomodoro'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Modos
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildModeButton('Foco', const Color(0xFFEF4444)),
                    _buildModeButton('Pausa Curta', const Color(0xFF10B981)),
                    _buildModeButton('Pausa Longa', const Color(0xFF3B82F6)),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Timer
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: CircularProgressIndicator(
                          value: _currentMode == 'Foco' 
                            ? _timeLeft / _workDuration 
                            : _currentMode == 'Pausa Curta'
                              ? _timeLeft / _shortBreakDuration
                              : _timeLeft / _longBreakDuration,
                          strokeWidth: 16,
                          backgroundColor: modeColor.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(modeColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_timeLeft),
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: modeColor,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentMode.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Controles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset Button
                  IconButton(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.replay_rounded),
                    iconSize: 32,
                    color: const Color(0xFF94A3B8),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shadowColor: Colors.black.withOpacity(0.05),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // Play / Pause Button
                  ElevatedButton(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      elevation: 8,
                      shadowColor: modeColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isRunning ? 'PAUSAR' : 'INICIAR',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Ciclos
              Text(
                'Ciclos concluídos: $_cycles',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, Color color) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          mode,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? color : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
