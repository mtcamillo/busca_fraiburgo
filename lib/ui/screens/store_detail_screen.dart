import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../providers/auth_provider.dart';

class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _store;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

    Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
        final s = await SupabaseService.client
            .from('stores')
            .select(
            'id,name,short_desc,instagram,whatsapp,phone,address_street,address_bairro,address_city,geo_lat,geo_lng,hours_json,verified'
            )
            .eq('id', widget.storeId)
            .single();

        _store = Map<String, dynamic>.from(s as Map);

        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
        final fav = await SupabaseService.client
            .from('favorites')
            .select('store_id')
            .eq('user_id', user.id)
            .eq('store_id', widget.storeId);

        _isFav = (fav as List).isNotEmpty;
        }
    } catch (_) {
        _error = 'Falha ao carregar loja';
    } finally {
        setState(() { _loading = false; });
    }
  }


  Future<void> _toggleFav() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre para favoritar')),
      );
      return;
    }
    try {
      if (_isFav) {
        await SupabaseService.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('store_id', widget.storeId);
      } else {
        await SupabaseService.client.from('favorites').insert({
          'user_id': user.id,
          'store_id': widget.storeId,
        });
      }
      setState(() { _isFav = !_isFav; });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar favorito')),
      );
    }
  }

  Future<void> _openWhatsApp(String raw) async {
    // aceita “5541999999999” ou “(49) 99999-9999”
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInstagram(String urlOrUser) async {
    final url = urlOrUser.startsWith('http')
        ? urlOrUser
        : 'https://instagram.com/${urlOrUser.replaceAll('@', '')}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMaps(double lat, double lng, String name) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng($name)');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatHours(dynamic hoursJson) {
    if (hoursJson == null) return 'Horários não informados';
    final map = (hoursJson is String) ? jsonDecode(hoursJson) : hoursJson as Map<String, dynamic>;
    final days = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
    final labels = ['Seg','Ter','Qua','Qui','Sex','Sáb','Dom'];
    final buf = <String>[];
    for (int i=0; i<days.length; i++) {
      final arr = (map[days[i]] ?? []) as List;
      final txt = arr.isEmpty ? 'fechado' : arr.map((e) => '${e['open']}-${e['close']}').join(', ');
      buf.add('${labels[i]}: $txt');
    }
    return buf.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null || _store == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error ?? 'Erro')));
    }

    final s = _store!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['name'] ?? ''),
        actions: [
          IconButton(
            onPressed: _toggleFav,
            icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((s['short_desc'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s['short_desc'], style: const TextStyle(fontSize: 16)),
            ),
          if (s['verified'] == true)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(children: [Icon(Icons.verified, color: Colors.blue), SizedBox(width: 6), Text('Perfil verificado')]),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(s['whatsapp'] ?? ''),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _openWhatsApp(s['whatsapp'] ?? ''),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
                ),
                if ((s['instagram'] ?? '').toString().isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: Text(s['instagram']),
                    trailing: OutlinedButton(
                      onPressed: () => _openInstagram(s['instagram']),
                      child: const Text('Abrir Instagram'),
                    ),
                  ),
                if ((s['address_street'] ?? '').toString().isNotEmpty || s['geo_lat'] != null)
                  ListTile(
                    leading: const Icon(Icons.place),
                    title: Text('${s['address_street'] ?? ''} - ${s['address_bairro'] ?? ''}, ${s['address_city'] ?? ''}'),
                    trailing: OutlinedButton(
                      onPressed: (s['geo_lat'] != null && s['geo_lng'] != null)
                          ? () => _openMaps((s['geo_lat'] as num).toDouble(), (s['geo_lng'] as num).toDouble(), s['name'])
                          : null,
                      child: const Text('Ver no mapa'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_formatHours(s['hours_json'])),
            ),
          ),
          if (!auth.isLoggedIn)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Entre para salvar favoritos.', textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}
