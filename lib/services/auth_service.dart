import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  /// UID do usuário autenticado, ou null se não houver sessão ativa
  static String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.events', // Permissão para adicionar eventos
    ],
  );

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

  Future<UserCredential?> loginComGoogle() async {
    try {
      if (kDebugMode) {
        print('[AuthService] Iniciando login com Google');
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (kDebugMode) {
          print('[AuthService] Login com Google cancelado pelo usuário');
        }
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      if (kDebugMode) {
        print(
          '[AuthService] Login com Google bem-sucedido: ${result.user?.email}',
        );
      }

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
          '[AuthService] Erro no login com Google: ${e.code} - ${e.message}',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('[AuthService] Erro desconhecido no login com Google: $e');
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      if (kDebugMode) {
        print('[AuthService] Fazendo logout');
      }
      await googleSignIn.signOut();
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
