import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

class StoreFormScreen extends StatefulWidget {
  final String? storeId;

  const StoreFormScreen({super.key, this.storeId});

  @override
  State<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends State<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _ruaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();

  String? _categoryId;

  String? _cidadeFromCep;
  String? _ufFromCep;

  double? _lat;
  double? _lng;

  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _categories = [];
  String? _mapsKey;
  bool _addressEdited = false;

  Map<String, dynamic> _hoursJson = _defaultHours();

  static Map<String, dynamic> _defaultHours() => {
        "tz": "America/Sao_Paulo",
        "monday": [
          {"open": "09:00", "close": "18:00"}
        ],
        "tuesday": [
          {"open": "09:00", "close": "18:00"}
        ],
        "wednesday": [
          {"open": "09:00", "close": "18:00"}
        ],
        "thursday": [
          {"open": "09:00", "close": "18:00"}
        ],
        "friday": [
          {"open": "09:00", "close": "18:00"}
        ],
        "saturday": [],
        "sunday": [],
      };

  @override
  void initState() {
    super.initState();
    _mapsKey = dotenv.env['GOOGLE_MAPS_KEY'];
    _cepCtrl.addListener(_onCepChanged);
    for (final c in [_ruaCtrl, _numeroCtrl, _bairroCtrl, _cepCtrl]) {
      c.addListener(() => _addressEdited = true);
    }

    _loadCategories();
    if (widget.storeId != null) {
      _loadStore(widget.storeId!); 
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    _descCtrl.dispose();

    _ruaCtrl.dispose();
    _numeroCtrl.dispose();
    _bairroCtrl.dispose();
    _cepCtrl.dispose();
    _cidadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await SupabaseService.client
          .from('categories')
          .select('id, name')
          .order('name');
      setState(() {
        _categories = List<Map<String, dynamic>>.from(res as List);
      });
    } catch (_) {
      setState(() => _error = 'Falha ao carregar categorias');
    }
  }

  Future<void> _loadStore(String id) async {
    try {
      final data = await SupabaseService.client
        .from('stores')
        .select('id, name, category_id, whatsapp, instagram, short_desc, '
                'address_street, address_number, address_bairro, address_cep, '
                'address_city, address_uf, '
                'geo_lat, geo_lng, hours_json')
        .eq('id', id)
        .maybeSingle();

      if (data != null) {
        _nameCtrl.text = (data['name'] ?? '') as String;
        _whatsappCtrl.text = (data['whatsapp'] ?? '') as String;
        _instagramCtrl.text = (data['instagram'] ?? '') as String;
        _descCtrl.text = (data['short_desc'] ?? '') as String;
        _categoryId = data['category_id']?.toString();
        _ruaCtrl.text    = (data['address_street'] ?? '') as String;
        _numeroCtrl.text = (data['address_number'] ?? '') as String;
        _bairroCtrl.text = (data['address_bairro'] ?? '') as String;
        _cepCtrl.text    = (data['address_cep'] ?? '') as String;
        _cidadeFromCep   = (data['address_city'] ?? '') as String?;
        _ufFromCep       = (data['address_uf'] ?? '') as String?;
        _cidadeCtrl.text = [
          _cidadeFromCep ?? '',
          if ((_ufFromCep ?? '').isNotEmpty) _ufFromCep
        ].where((e) => (e ?? '').isNotEmpty).join(' / ');

        _lat = (data['geo_lat'] as num?)?.toDouble();
        _lng = (data['geo_lng'] as num?)?.toDouble();

      final hj = data['hours_json'];
      if (hj is Map<String, dynamic>) {
        _hoursJson = {
          "tz": hj["tz"] ?? "America/Sao_Paulo",
          "monday": List<Map<String, dynamic>>.from(hj["monday"] ?? []),
          "tuesday": List<Map<String, dynamic>>.from(hj["tuesday"] ?? []),
          "wednesday": List<Map<String, dynamic>>.from(hj["wednesday"] ?? []),
          "thursday": List<Map<String, dynamic>>.from(hj["thursday"] ?? []),
          "friday": List<Map<String, dynamic>>.from(hj["friday"] ?? []),
          "saturday": List<Map<String, dynamic>>.from(hj["saturday"] ?? []),
          "sunday": List<Map<String, dynamic>>.from(hj["sunday"] ?? []),
        };
      }
      _addressEdited = false;

      setState(() {});
    }
    } catch (_) {
      setState(() => _error = 'Falha ao carregar a loja para edição.');
    }
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _onCepChanged() async {
    final raw = _digits(_cepCtrl.text);
    if (raw.length != 8) return;

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$raw/json/');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final map = json.decode(resp.body) as Map<String, dynamic>;
        if (map['erro'] == true) return;

        final cidade = (map['localidade'] as String?)?.trim();
        final uf = (map['uf'] as String?)?.trim();
        final bairroCep = (map['bairro'] as String?)?.trim();

        setState(() {
          _cidadeFromCep = cidade;
          _ufFromCep = uf;
          _cidadeCtrl.text = [
            cidade ?? '',
            if ((uf ?? '').isNotEmpty) uf
          ].where((e) => e!.isNotEmpty).join(' / ');

          if ((bairroCep != null && bairroCep.isNotEmpty) &&
              _bairroCtrl.text.trim().isEmpty) {
            _bairroCtrl.text = bairroCep;
          }
        });
      }
    } catch (_) {/* silencioso */}
  }

  String _normalizeStreet(String s) {
    var t = s.trim();
    final repl = <RegExp, String>{
      RegExp(r'^\s*av[.]?(\s|$)', caseSensitive: false): 'Avenida ',
      RegExp(r'^\s*r[.]?(\s|$)', caseSensitive: false): 'Rua ',
      RegExp(r'^\s*rod[.]?(\s|$)', caseSensitive: false): 'Rodovia ',
      RegExp(r'^\s*al[.]?(\s|$)', caseSensitive: false): 'Alameda ',
      RegExp(r'^\s*pq[.]?(\s|$)', caseSensitive: false): 'Parque ',
      RegExp(r'^\s*trav[.]?(\s|$)', caseSensitive: false): 'Travessa ',
    };
    for (final e in repl.entries) {
      t = t.replaceFirst(e.key, e.value);
    }
    return t;
  }

  Future<bool> _geocode() async {
    if (_mapsKey == null || _mapsKey!.isEmpty) {
      setState(() => _error = 'GOOGLE_MAPS_KEY ausente no .env');
      return false;
    }

    final rua = _normalizeStreet(_ruaCtrl.text);
    final numero = _numeroCtrl.text.trim();
    final bairro = _bairroCtrl.text.trim();
    final cep = _digits(_cepCtrl.text);
    final cidade = (_cidadeFromCep ?? '').trim();
    final uf = (_ufFromCep ?? '').trim();

    if (cidade.isEmpty || uf.isEmpty) {
      setState(() => _error = 'Informe um CEP válido para preencher cidade/UF.');
      return false;
    }

    final addrBase1 = '$rua, $numero - $bairro';
    final addrBase2 = '$rua, $numero';

    final urls = <Uri>[
      _geocodeUrl('$addrBase1, $cidade - $uf, Brasil',
          components: 'locality:$cidade|administrative_area:$uf|country:BR'),
      _geocodeUrl('$addrBase2, $cidade - $uf, Brasil',
          components: 'locality:$cidade|administrative_area:$uf|country:BR'),
      _geocodeUrl('$addrBase1, $cidade - $uf, Brasil'),
      _geocodeUrl('$addrBase2, $cidade - $uf, Brasil'),
      if (cep.isNotEmpty)
        _geocodeUrl('$addrBase1', components: 'postal_code:$cep|country:BR'),
      if (cep.isNotEmpty)
        _geocodeUrl('$addrBase2', components: 'postal_code:$cep|country:BR'),
    ];

    for (final url in urls) {
      final ok = await _tryGeocode(url);
      if (ok) return true;
    }

    setState(() => _error = 'Endereço não encontrado. Verifique rua/número/bairro/CEP.');
    return false;
  }

  Uri _geocodeUrl(String address, {String? components}) {
    final qp = <String, String>{
      'address': address,
      'key': _mapsKey!,
      'language': 'pt-BR',
      'region': 'br',
      if (components != null) 'components': components,
    };
    return Uri.https('maps.googleapis.com', '/maps/api/geocode/json', qp);
  }

  Future<bool> _tryGeocode(Uri url) async {
    try {
      final resp = await http.get(url);
      if (resp.statusCode != 200) return false;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? '';
      if (status != 'OK') {
        if (status == 'REQUEST_DENIED' || status == 'OVER_QUERY_LIMIT') {
          final msg = (data['error_message'] as String?) ?? '';
          setState(() => _error =
              'Geocoding: $status. ${msg.isNotEmpty ? msg : 'Verifique se a Geocoding API está habilitada e o billing ativo.'}');
          return false;
        }
        return false;
      }

      final results = (data['results'] as List?) ?? [];
      if (results.isEmpty) return false;

      final loc = results.first['geometry']?['location'];
      if (loc == null) return false;

      setState(() {
        _lat = (loc['lat'] as num?)?.toDouble();
        _lng = (loc['lng'] as num?)?.toDouble();
      });
      return _lat != null && _lng != null;
    } catch (_) {
      return false;
    }
  }

  bool _shouldGeocodeBeforeSave() {
    if (_addressEdited) return true;
    if (_lat == null || _lng == null) return true;
    return false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Você precisa estar logado para cadastrar/editar loja.');
      return;
    }
    if (_categoryId == null) {
      setState(() => _error = 'Selecione a categoria.');
      return;
    }

    setState(() => _error = null);

    if (_shouldGeocodeBeforeSave()) {
      final ok = await _geocode();
      if (!ok) return;
    }

    setState(() => _saving = true);

    try {
      final payload = <String, dynamic>{
        if (widget.storeId != null) 'id': widget.storeId,
        'user_id': user.id,
        'name': _nameCtrl.text.trim(),
        'category_id': _categoryId,
        'whatsapp': _whatsappCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'short_desc': _descCtrl.text.trim(),
        'address_street': _ruaCtrl.text.trim(),
        'address_number': _numeroCtrl.text.trim(),
        'address_bairro': _bairroCtrl.text.trim(),
        'address_cep': _cepCtrl.text.trim(),
        'address_city': _cidadeFromCep, 
        'address_uf': _ufFromCep,       

        'geo_lat': _lat,
        'geo_lng': _lng,
        'hours_json': _hoursJson,
        'status': 'published',
        'verified': false,
      };


      final res = await SupabaseService.client
          .from('stores')
          .upsert(payload)
          .select('id')
          .single();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.storeId == null
              ? 'Loja cadastrada com sucesso!'
              : 'Loja atualizada com sucesso!'),
        ),
      );
      Navigator.of(context).pop(res['id'] as String);
    } catch (e) {
      setState(() => _error = 'Falha ao salvar a loja. Verifique os dados.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openHoursEditor() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => HoursEditor(initial: _hoursJson),
    );

    if (result != null) {
      setState(() => _hoursJson = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    String _hoursSummary() {
      final days = [
        'monday','tuesday','wednesday','thursday','friday','saturday','sunday'
      ];
      int intervals = 0;
      for (final d in days) {
        intervals += (_hoursJson[d] as List).length;
      }
      return intervals == 0
          ? 'Sem horários definidos'
          : '$intervals intervalo(s) configurado(s)';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeId == null ? 'Cadastrar loja' : 'Editar loja'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.red.withOpacity(.1),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da loja *',
                    prefixIcon: Icon(Icons.store),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoria *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) =>
                      v == null ? 'Selecione a categoria' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _whatsappCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    prefixIcon: Icon(Icons.phone),
                    hintText: '5599999999999',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _instagramCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instagram',
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'ex.: @minhaloja',
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição breve',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Endereço',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _ruaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rua',
                    prefixIcon: Icon(Icons.signpost_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a rua' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _numeroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Número',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o número' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _bairroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bairro',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o bairro' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cepCtrl,
                  decoration: const InputDecoration(
                    labelText: 'CEP',
                    prefixIcon: Icon(Icons.local_post_office_outlined),
                    hintText: 'ex.: 89580000',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) =>
                      (v == null || v.replaceAll(RegExp(r'[^0-9]'), '').length != 8)
                          ? 'Informe um CEP válido (8 dígitos)'
                          : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cidadeCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Cidade (auto via CEP)',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // HORÁRIOS
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Horários'),
                  subtitle: Text(_hoursSummary()),
                  trailing: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Editar'),
                    onPressed: _openHoursEditor,
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving
                        ? 'Salvando...'
                        : (widget.storeId == null
                            ? 'Salvar loja'
                            : 'Atualizar loja')),
                    onPressed: _saving ? null : _submit,
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
class HoursEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  const HoursEditor({super.key, required this.initial});

  @override
  State<HoursEditor> createState() => _HoursEditorState();
}

class _HoursEditorState extends State<HoursEditor> {
  late Map<String, dynamic> _data;

  final _days = const [
    ['monday', 'Segunda'],
    ['tuesday', 'Terça'],
    ['wednesday', 'Quarta'],
    ['thursday', 'Quinta'],
    ['friday', 'Sexta'],
    ['saturday', 'Sábado'],
    ['sunday', 'Domingo'],
  ];

  @override
  void initState() {
    super.initState();
    _data = {
      "tz": widget.initial["tz"] ?? "America/Sao_Paulo",
      "monday": List<Map<String, dynamic>>.from(widget.initial["monday"] ?? []),
      "tuesday": List<Map<String, dynamic>>.from(widget.initial["tuesday"] ?? []),
      "wednesday": List<Map<String, dynamic>>.from(widget.initial["wednesday"] ?? []),
      "thursday": List<Map<String, dynamic>>.from(widget.initial["thursday"] ?? []),
      "friday": List<Map<String, dynamic>>.from(widget.initial["friday"] ?? []),
      "saturday": List<Map<String, dynamic>>.from(widget.initial["saturday"] ?? []),
      "sunday": List<Map<String, dynamic>>.from(widget.initial["sunday"] ?? []),
    };
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<String?> _pickTime(String initial) async {
    final parts = initial.split(':');
    final init = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final t = await showTimePicker(context: context, initialTime: init);
    if (t == null) return null;
    return '${_two(t.hour)}:${_two(t.minute)}';
  }

  bool _validateDay(List<Map<String, dynamic>> intervals) {
    int toMin(String hhmm) {
      final p = hhmm.split(':');
      final h = int.parse(p[0]);
      final m = int.parse(p[1]);
      return h * 60 + m;
    }

    intervals.sort((a, b) => toMin(a['open']).compareTo(toMin(b['open'])));

    for (int i = 0; i < intervals.length; i++) {
      final aOpen = toMin(intervals[i]['open']);
      final aClose = toMin(intervals[i]['close']);
      if (aOpen >= aClose) return false;

      if (i < intervals.length - 1) {
        final bOpen = toMin(intervals[i + 1]['open']);
        if (bOpen < aClose) return false;
      }
    }
    return true;
  }

  bool _validateAll() {
    for (final d in _days) {
      final key = d.first;
      final list = List<Map<String, dynamic>>.from(_data[key] as List);
      if (list.isEmpty) continue;
      if (!_validateDay(list)) return false;
      _data[key] = list;
    }
    return true;
  }

  Widget _intervalRow(String dayKey, int index) {
    final list = List<Map<String, dynamic>>.from(_data[dayKey] as List);
    final it = list[index];
    final open = it['open'] as String;
    final close = it['close'] as String;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.login),
            label: Text('Abre: $open'),
            onPressed: () async {
              final v = await _pickTime(open);
              if (v != null) {
                setState(() {
                  list[index]['open'] = v;
                  _data[dayKey] = list;
                });
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text('Fecha: $close'),
            onPressed: () async {
              final v = await _pickTime(close);
              if (v != null) {
                setState(() {
                  list[index]['close'] = v;
                  _data[dayKey] = list;
                });
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Remover intervalo',
          onPressed: () {
            setState(() {
              list.removeAt(index);
              _data[dayKey] = list;
            });
          },
          icon: const Icon(Icons.delete_outline),
        )
      ],
    );
  }

  Widget _dayCard(String key, String label) {
    final list = List<Map<String, dynamic>>.from(_data[key] as List);
    final isOpen = list.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Switch(
                  value: isOpen,
                  onChanged: (v) {
                    setState(() {
                      if (v) {
                        _data[key] = [
                          {"open": "09:00", "close": "12:00"},
                          {"open": "13:30", "close": "18:00"},
                        ];
                      } else {
                        _data[key] = [];
                      }
                    });
                  },
                ),
                Text(isOpen ? 'Aberto' : 'Fechado'),
              ],
            ),
            if (isOpen) const SizedBox(height: 8),
            if (isOpen)
              Column(
                children: [
                  for (int i = 0; i < list.length; i++) ...[
                    _intervalRow(key, i),
                    if (i < list.length - 1) const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar intervalo'),
                      onPressed: () {
                        setState(() {
                          list.add({"open": "09:00", "close": "18:00"});
                          _data[key] = list;
                        });
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text('Horários de funcionamento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    const Text(
                      'Adicione um ou mais intervalos por dia. Os horários não podem se sobrepor.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    for (final d in _days) _dayCard(d.first, d.last),
                    const SizedBox(height: 12),
                    Text(
                      'Fuso horário: ${_data["tz"]}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar horários'),
                      onPressed: () {
                        if (!_validateAll()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Verifique os horários: abertura < fechamento e sem sobreposição.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context, _data);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
