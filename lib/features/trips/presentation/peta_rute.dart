import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/config/napak_config.dart';
import '../../../core/theme/napak_colors.dart';
import '../data/trip_models.dart';

/// Satu garis rute di peta.
///
/// Pada Trip Bareng, tiap anggota punya jalurnya sendiri dengan warnanya
/// sendiri — warnanya datang dari server supaya konsisten di semua perangkat
/// yang sedang menonton peta yang sama.
@immutable
class JalurRute {
  const JalurRute({
    required this.id,
    required this.titik,
    this.warna,
    this.nama,
  });

  final String id;
  final List<LatLng> titik;

  /// Hex dari palet rute Napak. Kalau null, dipakai gradasi khas Napak.
  final String? warna;

  final String? nama;
}

/// Peta jejak.
///
/// Jalur milik sendiri digambar dengan gradasi Deep Accent Blue → Primary
/// Pastel Blue lewat `line-gradient` di atas sumber ber-`lineMetrics`: jejak
/// yang terasa mengalir, bukan garis datar. Jalur teman seperjalanan memakai
/// warna solid masing-masing supaya mudah dibedakan.
///
/// Yang penting soal performa: widget ini **tidak pernah dibangun ulang** saat
/// posisi baru masuk. Peta dibuat sekali, lalu isi sumber GeoJSON-nya
/// diperbarui lewat [PetaRuteController]. Membangun ulang MapLibreMap setiap
/// 30 detik akan menghabiskan baterai persis di saat perjalanan berlangsung.
class PetaRute extends StatefulWidget {
  const PetaRute({
    required this.jalur,
    this.interaktif = true,
    this.controller,
    super.key,
  });

  final List<JalurRute> jalur;
  final bool interaktif;
  final PetaRuteController? controller;

  @override
  State<PetaRute> createState() => _PetaRuteState();
}

/// Pegangan untuk mengubah isi peta tanpa membangun ulang petanya.
class PetaRuteController {
  _PetaRuteState? _state;

  /// Menambahkan satu titik ke ujung sebuah jalur yang sudah tergambar.
  Future<void> tambahTitik(
    String jalurId,
    LatLng titik, {
    bool ikutiKamera = true,
  }) async {
    await _state?._tambahTitik(jalurId, titik, ikutiKamera: ikutiKamera);
  }

  /// Perbarui penanda posisi langsung teman seperjalanan.
  Future<void> perbaruiPosisiLangsung(
    Iterable<PosisiLangsung> posisi,
    Map<String, String> warnaPerAnggota,
  ) async {
    await _state?._perbaruiPosisiLangsung(posisi, warnaPerAnggota);
  }

  Future<void> pasSemuaRute() async => _state?._pasSemuaRute();
}

class _PetaRuteState extends State<PetaRute> {
  static const _sumberUjung = 'napak-ujung';
  static const _lapisanUjung = 'napak-ujung-titik';
  static const _sumberLangsung = 'napak-langsung';
  static const _lapisanLangsung = 'napak-langsung-titik';
  static const _lapisanNamaLangsung = 'napak-langsung-nama';

  MapLibreMapController? _map;
  late final Map<String, List<LatLng>> _titikPerJalur = {
    for (final j in widget.jalur) j.id: List.of(j.titik),
  };
  late final Map<String, String?> _warnaPerJalur = {
    for (final j in widget.jalur) j.id: j.warna,
  };
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    super.dispose();
  }

  Iterable<LatLng> get _semuaTitik => _titikPerJalur.values.expand((t) => t);

  @override
  Widget build(BuildContext context) {
    final awal = _semuaTitik.isNotEmpty
        ? _semuaTitik.last
        // Monas, kalau belum ada jejak sama sekali.
        : const LatLng(-6.175392, 106.827153);

    return MapLibreMap(
      styleString: NapakConfig.mapStyleUrl,
      initialCameraPosition: CameraPosition(
        target: awal,
        zoom: _semuaTitik.isNotEmpty ? 11 : 4.5,
      ),
      onMapCreated: (controller) => _map = controller,
      onStyleLoadedCallback: _gambarSemua,
      scrollGesturesEnabled: widget.interaktif,
      zoomGesturesEnabled: widget.interaktif,
      rotateGesturesEnabled: widget.interaktif,
      tiltGesturesEnabled: false,
      compassEnabled: widget.interaktif,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
    );
  }

  Future<void> _gambarSemua() async {
    final map = _map;
    if (map == null) return;

    for (final jalur in widget.jalur) {
      await _pasangJalur(map, jalur.id, _warnaPerJalur[jalur.id]);
    }

    await map.addSource(
      _sumberUjung,
      GeojsonSourceProperties(data: _ujungGeoJson()),
    );
    await map.addCircleLayer(
      _sumberUjung,
      _lapisanUjung,
      const CircleLayerProperties(
        circleRadius: 6,
        circleColor: '#5C87B0',
        circleStrokeWidth: 3,
        circleStrokeColor: '#F5F9FC',
      ),
    );

    // Penanda posisi langsung, dipisah dari rute karena umurnya beda:
    // rute permanen, posisi ini hilang begitu layarnya ditutup.
    await map.addSource(
      _sumberLangsung,
      GeojsonSourceProperties(data: _kosongFeatureCollection()),
    );
    await map.addCircleLayer(
      _sumberLangsung,
      _lapisanLangsung,
      const CircleLayerProperties(
        circleRadius: 9,
        // Warna diambil dari properti tiap titik, jadi satu lapisan cukup
        // untuk seluruh rombongan.
        circleColor: ['get', 'warna'],
        circleStrokeWidth: 3,
        circleStrokeColor: '#F5F9FC',
      ),
    );
    await map.addSymbolLayer(
      _sumberLangsung,
      _lapisanNamaLangsung,
      const SymbolLayerProperties(
        textField: ['get', 'nama'],
        textSize: 12,
        textOffset: [0, 1.6],
        textColor: '#2E3B4E',
        textHaloColor: '#F5F9FC',
        textHaloWidth: 1.5,
      ),
    );

    _siap = true;
    await _pasSemuaRute();
  }

  Future<void> _pasangJalur(
    MapLibreMapController map,
    String jalurId,
    String? warna,
  ) async {
    final sumber = 'napak-rute-$jalurId';

    await map.addSource(
      sumber,
      GeojsonSourceProperties(
        data: _garisGeoJson(jalurId),
        // Tanpa ini, line-gradient tidak punya ukuran panjang untuk diacu.
        lineMetrics: warna == null,
      ),
    );

    await map.addLineLayer(
      sumber,
      'napak-garis-$jalurId',
      warna == null
          ? const LineLayerProperties(
              lineWidth: 4.5,
              lineCap: 'round',
              lineJoin: 'round',
              lineGradient: [
                'interpolate',
                ['linear'],
                ['line-progress'],
                0,
                '#5C87B0', // bagian rute yang sudah lama dilalui
                1,
                '#A8C8E8', // yang paling baru
              ],
            )
          : LineLayerProperties(
              lineWidth: 4.5,
              lineCap: 'round',
              lineJoin: 'round',
              lineColor: warna,
              lineOpacity: 0.9,
            ),
    );
  }

  /// Hanya isi sumber GeoJSON yang diperbarui — peta tidak dibangun ulang,
  /// tidak ada setState, tidak ada widget yang di-rebuild.
  Future<void> _tambahTitik(
    String jalurId,
    LatLng titik, {
    bool ikutiKamera = true,
  }) async {
    final daftar = _titikPerJalur[jalurId];
    if (daftar == null) return;
    daftar.add(titik);

    final map = _map;
    if (map == null || !_siap) return;

    await map.setGeoJsonSource('napak-rute-$jalurId', _garisGeoJson(jalurId));
    await map.setGeoJsonSource(_sumberUjung, _ujungGeoJson());

    if (ikutiKamera) {
      await map.animateCamera(CameraUpdate.newLatLng(titik));
    }
  }

  Future<void> _perbaruiPosisiLangsung(
    Iterable<PosisiLangsung> posisi,
    Map<String, String> warnaPerAnggota,
  ) async {
    final map = _map;
    if (map == null || !_siap) return;

    await map.setGeoJsonSource(_sumberLangsung, {
      'type': 'FeatureCollection',
      'features': [
        for (final p in posisi)
          {
            'type': 'Feature',
            'properties': {
              'nama': p.nama,
              'warna': warnaPerAnggota[p.userId] ?? '#5C87B0',
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [p.lng, p.lat],
            },
          },
      ],
    });
  }

  Future<void> _pasSemuaRute() async {
    final map = _map;
    final titik = _semuaTitik.toList();
    if (map == null || titik.length < 2) return;

    var selatan = titik.first.latitude;
    var utara = titik.first.latitude;
    var barat = titik.first.longitude;
    var timur = titik.first.longitude;

    for (final t in titik) {
      selatan = t.latitude < selatan ? t.latitude : selatan;
      utara = t.latitude > utara ? t.latitude : utara;
      barat = t.longitude < barat ? t.longitude : barat;
      timur = t.longitude > timur ? t.longitude : timur;
    }

    await map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(selatan, barat),
          northeast: LatLng(utara, timur),
        ),
        left: 48,
        right: 48,
        top: 72,
        bottom: 72,
      ),
    );
  }

  Map<String, dynamic> _garisGeoJson(String jalurId) {
    final titik = _titikPerJalur[jalurId] ?? const <LatLng>[];
    return {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          for (final t in titik) [t.longitude, t.latitude],
        ],
      },
    };
  }

  Map<String, dynamic> _ujungGeoJson() {
    final fitur = <Map<String, dynamic>>[];

    for (final entry in _titikPerJalur.entries) {
      final titik = entry.value;
      if (titik.isEmpty) continue;

      fitur.add(_titikFitur(titik.first, 'awal'));
      if (titik.length > 1) {
        fitur.add(_titikFitur(titik.last, 'akhir'));
      }
    }

    return {'type': 'FeatureCollection', 'features': fitur};
  }

  Map<String, dynamic> _titikFitur(LatLng titik, String jenis) => {
    'type': 'Feature',
    'properties': {'jenis': jenis},
    'geometry': {
      'type': 'Point',
      'coordinates': [titik.longitude, titik.latitude],
    },
  };

  Map<String, dynamic> _kosongFeatureCollection() => {
    'type': 'FeatureCollection',
    'features': <Map<String, dynamic>>[],
  };
}

/// Ditampilkan menggantikan peta saat sebuah perjalanan belum punya jejak.
class PetaKosong extends StatelessWidget {
  const PetaKosong({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NapakColors.softSky,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, size: 40, color: NapakColors.primary),
          const SizedBox(height: 14),
          Text(
            'Jejaknya belum tergambar',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
