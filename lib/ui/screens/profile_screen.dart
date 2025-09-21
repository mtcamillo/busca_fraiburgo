import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import 'auth/sign_in_screen.dart';
import 'store_form_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLogged = auth.isLoggedIn;

    final displayName = auth.user?.userMetadata?['name'] as String? ??
        auth.user?.email ??
        'usuário';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLogged) ...[
            const Text('Você não está logado.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                );
              },
              child: const Text('Entrar / Criar conta'),
            ),
          ] else ...[
            Text('Olá, $displayName'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Sair'),
            ),
            const SizedBox(height: 16),

            FilledButton.icon(
              icon: const Icon(Icons.add_business),
              label: const Text('Cadastre sua loja'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreFormScreen()),
                );
              },
            ),

            FutureBuilder(
              future: SupabaseService.client
                  .from('stores')
                  .select('id, name, verified')
                  .eq('user_id',
                      Supabase.instance.client.auth.currentUser!.id)
                  .order('name'),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                if (snap.hasError) return const SizedBox.shrink();

                final list = List<Map<String, dynamic>>.from(
                    (snap.data ?? []) as List);
                if (list.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text('Minhas lojas',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...list.map((s) => ListTile(
                          leading: const Icon(Icons.store),
                          title: Text(s['name'] ?? ''),
                          subtitle: Text(
                            (s['verified'] == true)
                                ? 'Verificada'
                                : 'Não verificada',
                          ),
                        )),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
