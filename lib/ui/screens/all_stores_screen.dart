import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import '../../utils/hours.dart';
import 'store_detail_screen.dart';

class AllStoresScreen extends StatefulWidget {
  const AllStoresScreen({super.key});

  @override
  State<AllStoresScreen> createState() => _AllStoresScreenState();
}

class _AllStoresScreenState extends State<AllStoresScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _stores = const [];
  List<Map<String, dynamic>> _categories = const [];

  String? _selectedCategoryId;
  bool _onlyOpen = false;
  bool _onlyVerified = false;
  String _search = '';

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _search = _searchCtrl.text.trim();
      });
      _fetchStores(); 
    });
  }

  Future<void> _init() async {
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
    } catch (_) {
      _error = 'Falha ao carregar categorias';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }

    await _fetchStores();
  }

    Future<void> _fetchStores() async {
    setState(() {
        _loading = true;
        _error = null;
    });

    try {
        var query = SupabaseService.client
            .from('stores')
            .select('id, name, short_desc, address_bairro, verified, image_url, hours_json, category_id')
            .eq('status', 'published');

        final catId = _selectedCategoryId;
        if (catId != null) {
        query = query.eq('category_id', catId);
        }

        if (_onlyVerified) {
        query = query.eq('verified', true);
        }

        final res = await query
            .order('verified', ascending: false)
            .order('name')
            .limit(200);

        var list = List<Map<String, dynamic>>.from(res as List);

        if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        list = list.where((s) {
            final name = (s['name'] ?? '').toString().toLowerCase();
            final desc = (s['short_desc'] ?? '').toString().toLowerCase();
            return name.contains(q) || desc.contains(q);
        }).toList();
        }

        if (_onlyOpen) {
        list = list.where((s) => computeOpenStatus(s['hours_json']).isOpen).toList();
        }

        setState(() {
        _stores = list;
        });
    } catch (_) {
        setState(() {
        _error = 'Falha ao carregar lojas';
        });
    } finally {
        if (mounted) {
        setState(() {
            _loading = false;
        });
        }
    }
    }


  Future<void> _refresh() async {
    await _fetchStores();
  }

  @override
  Widget build(BuildContext context) {
    final chipsBar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isDense: true,
                value: _selectedCategoryId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas as categorias'),
                  ),
                  ..._categories.map((c) => DropdownMenuItem<String?>(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedCategoryId = v;
                  });
                  _fetchStores();
                },
              ),
            ),
          ),

          FilterChip(
            label: const Text('Aberto agora'),
            selected: _onlyOpen,
            onSelected: (v) {
              setState(() {
                _onlyOpen = v;
              });
              _fetchStores();
            },
          ),

          FilterChip(
            label: const Text('Verificadas'),
            selected: _onlyVerified,
            onSelected: (v) {
              setState(() {
                _onlyVerified = v;
              });
              _fetchStores();
            },
          ),

          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStores,
          ),
        ],
      ),
    );

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar por nome ou descrição...',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );

    final listView = _loading && _stores.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!))
            : _stores.isEmpty
                ? const Center(child: Text('Nenhuma loja encontrada.'))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: _stores.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _stores[i];
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
                                // imagem
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
                                            placeholder: (_, __) =>
                                                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                            errorWidget: (_, __, ___) => const Icon(Icons.store, size: 40),
                                          )
                                        : const Center(child: Icon(Icons.store, size: 40)),
                                  ),
                                ),

                                // infos
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
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                                              Text(
                                                s['address_bairro'],
                                                style: const TextStyle(fontSize: 12),
                                              ),
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
                  );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lojas'),
      ),
      body: Column(
        children: [
          searchBar,
          chipsBar,
          const SizedBox(height: 4),
          Expanded(child: listView),
        ],
      ),
    );
  }
}
