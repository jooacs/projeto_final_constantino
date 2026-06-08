
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> login({
    required String email,
    required String senha,
  }) async {
    try {
      if (kDebugMode) {
        print('[AuthService] Tentando fazer login com: $email');
      }

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      if (kDebugMode) {
        print('[AuthService] Login bem-sucedido: ${result.user?.email}');
      }

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('[AuthService] Erro no login: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('[AuthService] Erro desconhecido no login: $e');
      }
      rethrow;
    }
  }

  Future<UserCredential> cadastrar({
    required String email,
    required String senha,
  }) async {
    try {
      if (kDebugMode) {
        print('[AuthService] Tentando cadastrar: $email');
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      if (kDebugMode) {
        print('[AuthService] Cadastro bem-sucedido: ${result.user?.email}');
      }

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('[AuthService] Erro no cadastro: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('[AuthService] Erro desconhecido no cadastro: $e');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      if (kDebugMode) {
        print('[AuthService] Fazendo logout');
      }
      await _auth.signOut();
      if (kDebugMode) {
        print('[AuthService] Logout bem-sucedido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AuthService] Erro no logout: $e');
      }
      rethrow;
    }
  }

  User? get usuarioAtual => _auth.currentUser;
}
