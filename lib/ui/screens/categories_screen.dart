import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'stores_by_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

// const Map<String, IconData> iconMap = {
//   'checkroom': Icons.checkroom,
//   'print': Icons.print,
//   'home_repair_service': Icons.home_repair_service,
//   'health_and_safety': Icons.health_and_safety,
//   'restaurant': Icons.restaurant,
//   'pet_supplies': Icons.pets,
//   'store': Icons.store,
//   'park': Icons.park,
// };

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.client
          .from('categories')
          .select('*')
          .order('name');

      _items = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _error = 'Falha ao carregar categorias';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) {
      return const Center(child: Text('Nenhuma categoria cadastrada ainda.'));
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final row = _items[i];
          final String name = (row['name'] ?? 'Sem nome') as String;
          // final String? iconKey = row['icon'] as String?;
          // final IconData leadingIcon = iconMap[iconKey] ?? Icons.help_outline;

          return Card(
            child: ListTile(
              // leading: Icon(leadingIcon),
              title: Text(name),
              // trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoresByCategoryScreen(
                      categoryId: row['id'] as String,
                      categoryName: name,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
