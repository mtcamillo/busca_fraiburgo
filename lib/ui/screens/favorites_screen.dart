import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'store_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String,dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _items = [];
      });
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('favorites')
          .select('store:stores(id,name,short_desc,verified)')
          .eq('user_id', user.id);
      final list = (res as List).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e['store'])).toList();
      setState(() { _items = list; });
    } catch (_) {
      setState(() { _error = 'Falha ao carregar favoritos'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Center(child: Text('Entre para ver favoritos.'));
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) return const Center(child: Text('Você ainda não tem favoritos.'));

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final s = _items[i];
          return Card(
            child: ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StoreDetailScreen(storeId: s['id'] as String),
              )),
              title: Row(
                children: [
                  Text(s['name'] ?? ''),
                  if (s['verified'] == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.verified, color: Colors.blue, size: 18),
                    ),
                ],
              ),
              subtitle: Text(s['short_desc'] ?? ''),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}
