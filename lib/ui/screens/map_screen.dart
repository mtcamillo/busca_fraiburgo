import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/supabase_service.dart';
import '../../utils/hours.dart';
import 'store_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _fraiburgo = LatLng(-27.0236, -50.9200);

  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  bool _onlyOpen = false;

  bool _loading = false;
  String? _error;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleFetchViewport() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fetchViewport);
  }

  Future<void> _fetchViewport() async {
    final c = _controller;
    if (c == null) return;

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final bounds = await c.getVisibleRegion();
      double minLat = bounds.southwest.latitude;
      double maxLat = bounds.northeast.latitude;
      double minLng = bounds.southwest.longitude;
      double maxLng = bounds.northeast.longitude;

      if (minLat > maxLat) {
        final t = minLat; minLat = maxLat; maxLat = t;
      }
      if (minLng > maxLng) {
        final t = minLng; minLng = maxLng; maxLng = t;
      }

      final res = await SupabaseService.client
          .from('stores')
          .select('id, name, short_desc, verified, geo_lat, geo_lng, hours_json')
          .eq('status', 'published')
          .gte('geo_lat', minLat)
          .lte('geo_lat', maxLat)
          .gte('geo_lng', minLng)
          .lte('geo_lng', maxLng)
          .limit(500);

      var list = List<Map<String, dynamic>>.from(res as List);

      if (_onlyOpen) {
        list = list.where((s) => computeOpenStatus(s['hours_json']).isOpen).toList();
      }

      final set = <Marker>{};
      for (final s in list) {
        final id = s['id'] as String;
        final name = (s['name'] ?? '') as String;
        final desc = (s['short_desc'] ?? '') as String;
        final lat = (s['geo_lat'] as num?)?.toDouble();
        final lng = (s['geo_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final open = computeOpenStatus(s['hours_json']);
        final hue = open.isOpen ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed;

        set.add(
          Marker(
            markerId: MarkerId(id),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(
              title: name,
              snippet: desc.isNotEmpty ? desc : open.label,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => StoreDetailScreen(storeId: id)),
                );
              },
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _markers
          ..clear()
          ..addAll(set);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao carregar lojas do mapa';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _recenter() {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _fraiburgo, zoom: 13),
      ),
    );
    _scheduleFetchViewport();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: _fraiburgo, zoom: 13),
          onMapCreated: (c) {
            _controller = c;
            _scheduleFetchViewport();
          },
          onCameraIdle: _scheduleFetchViewport, 
          onCameraMove: (_) => _debounce?.cancel(), 
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: _markers,
        ),

        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(999),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Aberto agora'),
                    selected: _onlyOpen,
                    onSelected: (v) {
                      setState(() => _onlyOpen = v);
                      _scheduleFetchViewport();
                    },
                  ),
                  const Spacer(),
                  if (_loading) const SizedBox(width: 8),
                  if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  IconButton(
                    tooltip: 'Recarregar',
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchViewport,
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_error != null)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),

        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: _recenter,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
