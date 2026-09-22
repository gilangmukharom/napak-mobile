import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/config/tourvella_config.dart';
import '../../../core/theme/tourvella_colors.dart';
import '../data/trip_models.dart';
import 'penanda_kendaraan.dart';

export 'penanda_kendaraan.dart' show ModaPenanda;

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

  /// Hex dari palet rute Tourvella. Kalau null, dipakai gradasi khas Tourvella.
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
    this.kendaraan = const {},
    super.key,
  });

  final List<JalurRute> jalur;
  final bool interaktif;
  final PetaRuteController? controller;

  /// Jalur yang ujungnya sedang bergerak, dengan kendaraannya.
  ///
  /// Hanya untuk perjalanan yang sedang direkam. Ujung perjalanan yang sudah
  /// selesai adalah tempat tujuan, bukan motor yang masih jalan — di sana
  /// tetap titik biasa.
  final Map<String, ModaPenanda> kendaraan;

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

  /// Mengganti isi satu jalur — dipakai rute navigasi yang dihitung ulang
  /// saat keluar jalur. Jalur yang belum ada akan dibuat.
  Future<void> gantiJalur(
    String jalurId,
    List<LatLng> titik, {
    String? warna,
  }) async {
    await _state?._gantiJalur(jalurId, titik, warna: warna);
  }
}

class _PetaRuteState extends State<PetaRute> {
  static const _sumberUjung = 'tourvella-ujung';
  static const _lapisanUjung = 'tourvella-ujung-titik';
  static const _sumberKendaraan = 'tourvella-kendaraan';
  static const _lapisanRiak = 'tourvella-kendaraan-riak';
  static const _lapisanKendaraan = 'tourvella-kendaraan-ikon';

  /// Kendaraan sendiri memakai Deep Accent — biru yang sama dengan pangkal
  /// garis rutenya, jadi terbaca sebagai "ujung jejakku".
  static const _warnaKendaraanSendiri = '#5C87B0';

  MapLibreMapController? _map;
  late final _luncuran = LuncuranKendaraan(gambar: _gambarKendaraan);
  final _ikonTerdaftar = <String>{};
  double _rasioPiksel = 3;
  bool _sedangMenggambar = false;
  Map<String, dynamic>? _bingkaiTertunda;
  late final Map<String, List<LatLng>> _titikPerJalur = {
    for (final j in widget.jalur) j.id: List.of(j.titik),
  };
  late final Map<String, String?> _warnaPerJalur = {
    for (final j in widget.jalur) j.id: j.warna,
  };
  late final Map<String, String?> _namaJalur = {
    for (final j in widget.jalur) j.id: j.nama,
  };
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    _luncuran.dispose();
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rasioPiksel = MediaQuery.devicePixelRatioOf(context);
  }

  /// Mengirim satu bingkai kendaraan ke peta.
  ///
  /// Kalau bingkai sebelumnya belum selesai menyeberang ke peta native, yang
  /// baru tidak diantrekan — hanya yang terbaru yang disimpan. Antrean
  /// bingkai yang menumpuk berarti kendaraan yang tertinggal di belakang
  /// posisinya sendiri.
  Future<void> _gambarKendaraan(Map<String, dynamic> isi) async {
    final map = _map;
    if (map == null || !_siap) return;
    if (_sedangMenggambar) {
      _bingkaiTertunda = isi;
      return;
    }

    _sedangMenggambar = true;
    try {
      for (final (moda, warna, cermin) in _luncuran.ikonDibutuhkan) {
        final nama = namaIkonKendaraan(moda, warna, cermin);
        if (!_ikonTerdaftar.add(nama)) continue;
        await map.addImage(
          nama,
          await gambarPenandaKendaraan(
            moda: moda,
            warna: warna,
            cermin: cermin,
            rasioPiksel: _rasioPiksel,
          ),
        );
      }
      await map.setGeoJsonSource(_sumberKendaraan, isi);
    } finally {
      _sedangMenggambar = false;
    }

    final tertunda = _bingkaiTertunda;
    _bingkaiTertunda = null;
    if (tertunda != null) await _gambarKendaraan(tertunda);
  }

  Iterable<LatLng> get _semuaTitik => _titikPerJalur.values.expand((t) => t);

  @override
  Widget build(BuildContext context) {
    final awal = _semuaTitik.isNotEmpty
        ? _semuaTitik.last
        // Monas, kalau belum ada jejak sama sekali.
        : const LatLng(-6.175392, 106.827153);

    return MapLibreMap(
      styleString: TourvellaConfig.mapStyleUrl,
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

    // Kendaraan: ujung jejak yang sedang direkam dan posisi langsung teman.
    // Dipisah dari rute karena umurnya beda — rute permanen, kendaraan ini
    // hilang begitu layarnya ditutup.
    await map.addSource(
      _sumberKendaraan,
      GeojsonSourceProperties(data: _kosongFeatureCollection()),
    );
    await map.addCircleLayer(
      _sumberKendaraan,
      _lapisanRiak,
      const CircleLayerProperties(
        // Riak melebar dan memudar sekali tiap posisi baru masuk: tanda
        // "masih jalan" tanpa animasi yang terus menyala.
        circleRadius: [
          'interpolate',
          ['linear'],
          ['get', 'riak'],
          0,
          18,
          1,
          38,
        ],
        circleOpacity: [
          'interpolate',
          ['linear'],
          ['get', 'riak'],
          0,
          0.45,
          1,
          0,
        ],
        // Warna dari properti tiap kendaraan, jadi satu lapisan cukup untuk
        // seluruh rombongan.
        circleColor: ['get', 'warna'],
      ),
    );
    await map.addSymbolLayer(
      _sumberKendaraan,
      _lapisanKendaraan,
      const SymbolLayerProperties(
        iconImage: ['get', 'ikon'],
        iconRotate: ['get', 'putar'],
        // Ikut berputar bersama peta: motor ke utara tetap menghadap utara
        // saat petanya diputar.
        iconRotationAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        textField: ['get', 'nama'],
        textSize: 12,
        textOffset: [0, 2.3],
        textAllowOverlap: true,
        textColor: '#2E3B4E',
        textHaloColor: '#F5F9FC',
        textHaloWidth: 1.5,
      ),
    );

    _siap = true;

    // Kendaraan sendiri diletakkan di titik kedua terakhir lalu dijalankan ke
    // ujungnya: arahnya langsung benar, dan layar dibuka dengan kendaraan
    // yang bergerak, bukan ikon yang tertancap.
    for (final MapEntry(key: jalurId, value: moda) in widget.kendaraan.entries) {
      final titik = _titikPerJalur[jalurId] ?? const <LatLng>[];
      for (final t in titik.skip(titik.length > 1 ? titik.length - 2 : 0)) {
        _luncuran.atur(
          'jalur:$jalurId',
          posisi: t,
          moda: moda,
          warna: _warnaPerJalur[jalurId] ?? _warnaKendaraanSendiri,
          // Namanya ikut di bawah ikon, sama seperti teman seperjalanan —
          // di peta yang ramai, kendaraan tanpa nama bikin bingung sendiri.
          nama: _namaJalur[jalurId] ?? 'Kamu',
        );
      }
    }

    await _pasSemuaRute();
  }

  Future<void> _pasangJalur(
    MapLibreMapController map,
    String jalurId,
    String? warna, {
    String? diBawah,
  }) async {
    final sumber = 'tourvella-rute-$jalurId';

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
      'tourvella-garis-$jalurId',
      belowLayerId: diBawah,
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

    await map.setGeoJsonSource('tourvella-rute-$jalurId', _garisGeoJson(jalurId));
    await map.setGeoJsonSource(_sumberUjung, _ujungGeoJson());

    final moda = widget.kendaraan[jalurId];
    if (moda != null) {
      _luncuran.atur(
        'jalur:$jalurId',
        posisi: titik,
        moda: moda,
        warna: _warnaPerJalur[jalurId] ?? _warnaKendaraanSendiri,
        nama: _namaJalur[jalurId] ?? 'Kamu',
      );
    }

    if (ikutiKamera) {
      await map.animateCamera(CameraUpdate.newLatLng(titik));
    }
  }

  Future<void> _gantiJalur(
    String jalurId,
    List<LatLng> titik, {
    String? warna,
  }) async {
    final map = _map;
    final baru = !_titikPerJalur.containsKey(jalurId);
    _titikPerJalur[jalurId] = List.of(titik);
    _warnaPerJalur[jalurId] ??= warna;
    if (map == null || !_siap) return;

    if (baru) {
      // Rute navigasi digambar di bawah jejakmu sendiri: yang kamu buat
      // tetap yang paling menonjol, panduannya jadi latar.
      await _pasangJalur(
        map,
        jalurId,
        _warnaPerJalur[jalurId],
        diBawah: widget.jalur.isEmpty
            ? null
            : 'tourvella-garis-${widget.jalur.first.id}',
      );
    } else {
      await map.setGeoJsonSource(
        'tourvella-rute-$jalurId',
        _garisGeoJson(jalurId),
      );
    }
  }

  Future<void> _perbaruiPosisiLangsung(
    Iterable<PosisiLangsung> posisi,
    Map<String, String> warnaPerAnggota,
  ) async {
    if (_map == null || !_siap) return;

    final ada = <String>{
      for (final id in widget.kendaraan.keys) 'jalur:$id',
    };
    for (final p in posisi) {
      final id = 'orang:${p.userId}';
      ada.add(id);
      _luncuran.atur(
        id,
        posisi: LatLng(p.lat, p.lng),
        moda: ModaPenanda.dari(p.moda),
        warna: warnaPerAnggota[p.userId] ?? _warnaKendaraanSendiri,
        nama: p.nama,
      );
    }
    _luncuran.sisakan(ada);
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
      // Ujung yang sedang bergerak sudah digambar sebagai kendaraan.
      if (titik.length > 1 && !widget.kendaraan.containsKey(entry.key)) {
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
      color: TourvellaColors.softSky,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 40,
            color: TourvellaColors.primary,
          ),
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
