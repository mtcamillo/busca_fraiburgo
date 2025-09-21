import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/hours.dart';
import 'store_detail_screen.dart';

class StoresByCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  const StoresByCategoryScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  State<StoresByCategoryScreen> createState() => _StoresByCategoryScreenState();
}

class _StoresByCategoryScreenState extends State<StoresByCategoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  bool _onlyOpen = false; 

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await SupabaseService.client
          .from('stores')
          .select('id, name, short_desc, address_bairro, verified, image_url, hours_json')
          .eq('category_id', widget.categoryId)
          .eq('status', 'published')
          .order('verified', ascending: false)
          .order('name');

      _items = List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      _error = 'Falha ao carregar lojas';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = !_onlyOpen
        ? _items
        : _items.where((s) => computeOpenStatus(s['hours_json']).isOpen).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('Nenhuma loja nessa categoria.'))
                  : Column(
                      children: [
                        // Filtro
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Aberto agora'),
                                selected: _onlyOpen,
                                onSelected: (v) => setState(() => _onlyOpen = v),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Atualizar',
                                icon: const Icon(Icons.refresh),
                                onPressed: _fetch,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Lista
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetch,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final s = list[i];
                                final status = computeOpenStatus(s['hours_json']);

                                return InkWell(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StoreDetailScreen(storeId: s['id'] as String),
                                    ),
                                  ),
                                  child: Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                    ),
                                    child: Row(
                                      children: [
                                        // Imagem
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                          ),
                                          child: SizedBox(
                                            width: 96,
                                            height: 96,
                                            child: (s['image_url'] != null && (s['image_url'] as String).isNotEmpty)
                                                ? CachedNetworkImage(
                                                    imageUrl: s['image_url'],
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                    errorWidget: (_, __, ___) => const Icon(Icons.store, size: 40),
                                                  )
                                                : const Center(child: Icon(Icons.store, size: 40)),
                                          ),
                                        ),

                                        // Infos
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        s['name'] ?? '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                    if (s['verified'] == true)
                                                      const Padding(
                                                        padding: EdgeInsets.only(left: 6),
                                                        child: Icon(Icons.verified, color: Colors.blue, size: 18),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if ((s['short_desc'] ?? '').toString().isNotEmpty)
                                                  Text(
                                                    s['short_desc'],
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    if ((s['address_bairro'] ?? '').toString().isNotEmpty) ...[
                                                      const Icon(Icons.place, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(s['address_bairro'], style: const TextStyle(fontSize: 12)),
                                                      const SizedBox(width: 10),
                                                    ],
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: status.isOpen
                                                            ? Colors.green.withOpacity(0.15)
                                                            : Colors.red.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(999),
                                                      ),
                                                      child: Text(
                                                        status.label,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: status.isOpen ? Colors.green[800] : Colors.red[800],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(Icons.chevron_right),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
