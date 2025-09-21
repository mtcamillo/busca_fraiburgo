import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  Session? _session;

  AuthProvider() {
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      notifyListeners();
    });

    _session = SupabaseService.client.auth.currentSession;
  }

  bool get isLoggedIn => _session != null;
  User? get user => _session?.user;

  Future<String?> signIn(String email, String password) async {
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null; 
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erro inesperado ao entrar';
    }
  }

  Future<String?> signUp(String name, String phone, String email, String password) async {
    try {
      final res = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name,
          'phone': phone,
        },
      );

      final uid = res.user?.id;
      if (uid != null) {
        await SupabaseService.client.from('users').insert({
          'id': uid,
          'name': name,
          'phone': phone,
          'email': email.trim(),
          'role': 'user',
        });
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erro inesperado ao cadastrar';
    }
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }
}
