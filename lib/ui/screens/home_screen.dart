import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'store_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _featured = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await SupabaseService.client
          .from('categories')
          .select('id, name')
          .order('name');
      _categories = List<Map<String, dynamic>>.from(cats as List);

      List<Map<String, dynamic>> stores;
      try {
        final res = await SupabaseService.client
          .from('v_stores_cover')
          .select('id, name, short_desc, verified, cover_path, image_url, status')
          .eq('status', 'published')
          .order('verified', ascending: false)
          .order('name')
          .limit(12);
        stores = List<Map<String, dynamic>>.from(res as List);
      } catch (_) {
        final res = await SupabaseService.client
            .from('stores')
            .select('id, name, short_desc, verified, image_url, status')
            .eq('status', 'published')
            .order('verified', ascending: false)
            .order('name')
            .limit(12);
        stores = List<Map<String, dynamic>>.from(res as List);
      }

      _featured = stores;
    } catch (e) {
      _error = 'Falha ao carregar conteúdo';
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String? _coverUrl(Map<String, dynamic> s) {
    final coverPath = (s['cover_path'] as String?)?.trim();
    final imageUrl = (s['image_url'] as String?)?.trim();

    if (coverPath != null && coverPath.isNotEmpty) {
      // getPublicUrl retorna String na 2.x
      final url = SupabaseService.client.storage
          .from('store-images')
          .getPublicUrl(coverPath);
      return url;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    return null;
  }

  void _openSearch() {
    showSearch(context: context, delegate: _StoreSearchDelegate());
  }

  void _openCategory(Map<String, dynamic> c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StoresByCategoryPage(
          categoryId: c['id'] as String,
          categoryName: c['name'] as String,
        ),
      ),
    );
  }

  void _openStore(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: _openSearch,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 8),
                  Text(
                    'Buscar lojas ou categorias…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Text('Categorias', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_categories.isNotEmpty)
                Text('${_categories.length} tipos',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                return ActionChip(
                  label: Text(c['name'] as String),
                  onPressed: () => _openCategory(c),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Text('Lojas em destaque',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),

          if (_featured.isEmpty)
            Text('Nenhuma loja em destaque ainda.',
                style: Theme.of(context).textTheme.bodySmall),

          if (_featured.isNotEmpty)
            SizedBox(
              height: 480, 
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: PageController(viewportFraction: 0.92),
                itemCount: _featured.length,
                itemBuilder: (_, i) {
                  final s = _featured[i];
                  return _FeaturedCard(
                    title: s['name'] as String? ?? '',
                    desc: s['short_desc'] as String? ?? '',
                    verified: s['verified'] == true,
                    imageUrl: _coverUrl(s),
                    onTap: () => _openStore(s['id'] as String),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final String title;
  final String desc;
  final bool verified;
  final String? imageUrl;
  final VoidCallback onTap;

  const _FeaturedCard({
    required this.title,
    required this.desc,
    required this.verified,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          height: 280, // mantém exatamente igual ao SizedBox
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl!.isNotEmpty)
                        Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black12,
                            child: const Icon(Icons.image_not_supported),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.black12,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: Colors.black12,
                          child: Icon(
                            verified ? Icons.verified : Icons.store,
                            size: 56,
                            color: verified ? Colors.blue : Colors.black26,
                          ),
                        ),
                      if (verified)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Verificada',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!verified)
                        const Icon(Icons.store, size: 20)
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              (desc.isEmpty ? '—' : desc),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SearchDelegate e _StoresByCategoryPage (iguais à versão anterior) --------------------

class _StoreSearchDelegate extends SearchDelegate<String?> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      _results = [];
      return;
    }
    _loading = true;
    try {
      final stores = await SupabaseService.client
          .from('stores')
          .select('id, name, short_desc')
          .ilike('name', '%$q%')
          .eq('status', 'published')
          .limit(30);

      _results = List<Map<String, dynamic>>.from(stores as List);
    } finally {
      _loading = false;
    }
  }

  @override
  String? get searchFieldLabel => 'Buscar lojas…';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder(
      future: _search(query),
      builder: (_, __) {
        if (_loading) return const Center(child: CircularProgressIndicator());
        if (_results.isEmpty) return const Center(child: Text('Nenhum resultado'));
        return ListView.separated(
          itemCount: _results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = _results[i];
            return ListTile(
              leading: const Icon(Icons.store),
              title: Text(s['name'] as String? ?? ''),
              subtitle: Text(s['short_desc'] as String? ?? ''),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoreDetailScreen(storeId: s['id'] as String),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(child: Text('Digite para buscar lojas'));
  }
}

class _StoresByCategoryPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  const _StoresByCategoryPage({
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<_StoresByCategoryPage> createState() => _StoresByCategoryPageState();
}

class _StoresByCategoryPageState extends State<_StoresByCategoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _stores = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.client
          .from('stores')
          .select('id, name, short_desc, verified')
          .eq('status', 'published')
          .eq('category_id', widget.categoryId)
          .order('verified', ascending: false)
          .order('name');

      _stores = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _error = 'Falha ao carregar lojas';
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _stores.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = _stores[i];
                    return ListTile(
                      leading: Icon(
                        s['verified'] == true ? Icons.verified : Icons.store,
                        color: s['verified'] == true ? Colors.blue : null,
                      ),
                      title: Text(s['name'] as String? ?? ''),
                      subtitle: Text(s['short_desc'] as String? ?? ''),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                StoreDetailScreen(storeId: s['id'] as String),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
