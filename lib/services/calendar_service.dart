import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:projeto_flutter/models/prova.dart';
import 'package:projeto_flutter/models/tarefa.dart';
import 'package:projeto_flutter/services/auth_service.dart';

class CalendarService {
  final AuthService _authService = AuthService();

  Future<calendar.CalendarApi?> _getCalendarApi() async {
    try {
      final googleSignIn = _authService.googleSignIn;
      // Precisamos garantir que o usuário está autenticado via Google no dispositivo.
      var currentUser = googleSignIn.currentUser;
      if (currentUser == null) {
        // Tenta recuperar a sessão silenciosamente caso exista
        currentUser = await googleSignIn.signInSilently();
      }

      if (currentUser == null) {
        if (kDebugMode) {
          print('[CalendarService] Usuário não autenticado pelo Google.');
        }
        return null;
      }

      // Obtém um client autenticado a partir do google_sign_in
      final httpClient = await googleSignIn.authenticatedClient();
      if (httpClient == null) {
        if (kDebugMode) {
          print('[CalendarService] Falha ao obter o HTTP client autenticado.');
        }
        return null;
      }

      return calendar.CalendarApi(httpClient);
    } catch (e) {
      if (kDebugMode) {
        print('[CalendarService] Erro ao instanciar API do calendário: $e');
      }
      return null;
    }
  }

  Future<bool> inserirEventoTarefa(Tarefa tarefa) async {
    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final event = calendar.Event(
        summary: 'Tarefa: ${tarefa.titulo}',
        description: tarefa.descricao,
        start: calendar.EventDateTime(
          dateTime: tarefa.dataEntrega ?? DateTime.now(),
          timeZone: 'America/Sao_Paulo', // TODO: Pode ser dinâmico no futuro
        ),
        end: calendar.EventDateTime(
          // Assumindo duração de 1h como padrão para tarefas
          dateTime: (tarefa.dataEntrega ?? DateTime.now()).add(const Duration(hours: 1)),
          timeZone: 'America/Sao_Paulo',
        ),
      );

      final result = await api.events.insert(event, 'primary');
      if (kDebugMode) {
        print('[CalendarService] Evento de Tarefa criado: ${result.htmlLink}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[CalendarService] Erro ao inserir tarefa no calendário: $e');
      }
      return false;
    }
  }

  Future<bool> inserirEventoProva(Prova prova) async {
    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final event = calendar.Event(
        summary: 'Prova: ${prova.titulo}',
        description: 'Matéria ID: ${prova.idMateria}\nConteúdo: ${prova.descricao}',
        start: calendar.EventDateTime(
          dateTime: prova.dataProva ?? DateTime.now(),
          timeZone: 'America/Sao_Paulo',
        ),
        end: calendar.EventDateTime(
          // Assumindo duração de 2h como padrão para provas
          dateTime: (prova.dataProva ?? DateTime.now()).add(const Duration(hours: 2)),
          timeZone: 'America/Sao_Paulo',
        ),
      );

      final result = await api.events.insert(event, 'primary');
      if (kDebugMode) {
        print('[CalendarService] Evento de Prova criado: ${result.htmlLink}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[CalendarService] Erro ao inserir prova no calendário: $e');
      }
      return false;
    }
  }
}
