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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            const Spacer(),


            FutureBuilder(
              future: SupabaseService.client
                  .from('stores')
                  .select('id, name, verified')
                  .eq('user_id',
                      Supabase.instance.client.auth.currentUser!.id)
                  .order('name'),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 80);
                }
                if (snap.hasError) {
                  return const Text('Erro ao carregar suas lojas.');
                }

                final list = List<Map<String, dynamic>>.from(
                    (snap.data ?? []) as List);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 6,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minhas lojas',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),

                      if (list.isEmpty) ...[
                        const Text('Você ainda não cadastrou nenhuma loja.'),
                      ] else ...[
                        ...list.map(
                          (s) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.store),
                            title: Text(s['name'] ?? ''),
                            subtitle: Text(
                              (s['verified'] == true)
                                  ? 'Verificada'
                                  : 'Em análise',
                            ),
                            trailing: IconButton(
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StoreFormScreen(
                                      storeId: s['id'] as String,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ).toList(),
                      ],

                      const SizedBox(height: 16),

                      Center(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add_business),
                          label: const Text('cadastre sua loja'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StoreFormScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Sair'),
            ),
          ],
        ],
      ),
    );
  }
}
