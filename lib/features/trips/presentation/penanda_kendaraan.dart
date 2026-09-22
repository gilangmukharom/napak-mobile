import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/theme/tourvella_colors.dart';
import '../../../core/theme/tourvella_motion.dart';

/// Kendaraan yang digambar di ujung jejak dan di posisi teman seperjalanan.
///
/// Bentuknya sama dengan siluet di video animasi (`vehicle-glyphs.ts` di
/// backend): kotak 24×24, menghadap ke kanan. Kendaraan di aplikasi dan di
/// video yang dibagikan harus terlihat satu keluarga.
enum ModaPenanda {
  motor('motor'),
  mobil('mobil'),
  sepeda('sepeda'),
  jalanKaki('jalan_kaki'),
  lainnya('lainnya');

  const ModaPenanda(this.wire);
  final String wire;

  /// Kereta, kapal, dan pesawat jarang dipakai saat konvoi; digambar sebagai
  /// panah arah, bukan ditebak jadi motor.
  static ModaPenanda dari(String? wire) => switch (wire) {
    'motor' => motor,
    'mobil' => mobil,
    'sepeda' => sepeda,
    'jalan_kaki' => jalanKaki,
    _ => lainnya,
  };
}

/// Cara menampilkan kendaraan yang menuju arah tertentu.
///
/// Siluetnya menghadap ke kanan. Motor yang berjalan ke barat akan terbalik
/// kalau diputar 180°, jadi yang dilakukan sama seperti di video: dicerminkan,
/// lalu diputar sisanya. Kendaraan tidak pernah terlihat jungkir balik.
@immutable
class ArahTampil {
  const ArahTampil({required this.cermin, required this.putar});

  /// Ditentukan dari arah kompas: 0 = utara, 90 = timur.
  factory ArahTampil.dariArah(double arahDerajat) {
    // Siluet menghadap timur, jadi 90° kompas = tanpa putaran.
    var sudut = (arahDerajat - 90) % 360;
    if (sudut > 180) sudut -= 360;
    if (sudut <= -180) sudut += 360;

    if (sudut.abs() <= 90) return ArahTampil(cermin: false, putar: sudut);
    return ArahTampil(
      cermin: true,
      putar: sudut > 0 ? sudut - 180 : sudut + 180,
    );
  }

  final bool cermin;

  /// Derajat searah jarum jam, seperti `icon-rotate` MapLibre.
  final double putar;
}

/// Arah kompas dari [a] ke [b], derajat 0..360.
double arahKompas(LatLng a, LatLng b) {
  final p1 = a.latitude * math.pi / 180;
  final p2 = b.latitude * math.pi / 180;
  final dl = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x =
      math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Jarak kasar dalam meter — cukup untuk memutuskan "sudah berpindah".
double jarakKasarM(LatLng a, LatLng b) {
  final dLat = (b.latitude - a.latitude) * 111320;
  final dLng =
      (b.longitude - a.longitude) *
      111320 *
      math.cos(a.latitude * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

/// Nama gambar di gaya peta untuk satu kombinasi kendaraan/warna/arah.
String namaIkonKendaraan(ModaPenanda moda, String warna, bool cermin) =>
    'kendaraan-${moda.wire}-${warna.replaceAll('#', '').toLowerCase()}-${cermin ? 'c' : 'k'}';

/// Ukuran penanda di layar, piksel logis.
const double ukuranPenanda = 52;

/// Menggambar satu penanda kendaraan sebagai PNG.
///
/// Digambar pada rasio piksel layar: iOS membaca gambar MapLibre dengan skala
/// layar, Android dengan kepadatan layar — dua-duanya berarti PNG ini harus
/// seukuran piksel sungguhan, bukan piksel logis.
Future<Uint8List> gambarPenandaKendaraan({
  required ModaPenanda moda,
  required String warna,
  required bool cermin,
  required double rasioPiksel,
}) async {
  final sisi = (ukuranPenanda * rasioPiksel).round();
  final perekam = ui.PictureRecorder();
  final kanvas = Canvas(perekam)..scale(rasioPiksel);
  final pusat = const Offset(ukuranPenanda / 2, ukuranPenanda / 2);
  final aksen = _warnaDariHex(warna);

  // Bayangan lembut supaya terbaca di atas peta terang maupun rute berwarna.
  kanvas.drawCircle(
    pusat.translate(0, 1.5),
    20,
    Paint()
      ..color = TourvellaColors.textPrimary.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  kanvas.drawCircle(pusat, 19, Paint()..color = TourvellaColors.base);
  kanvas.drawCircle(
    pusat,
    19,
    Paint()
      ..color = aksen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );

  kanvas
    ..save()
    ..translate(pusat.dx, pusat.dy);
  if (cermin) kanvas.scale(-1, 1);
  kanvas
    ..scale(1.3)
    ..translate(-12, -12);
  _gambarSiluet(kanvas, moda, aksen);
  kanvas.restore();

  final gambar = await perekam.endRecording().toImage(sisi, sisi);
  final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
  gambar.dispose();
  return data!.buffer.asUint8List();
}

void _gambarSiluet(Canvas k, ModaPenanda moda, Color warna) {
  final garis = Paint()
    ..color = warna
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Path jalur(List<Offset> titik) {
    final p = Path()..moveTo(titik.first.dx, titik.first.dy);
    for (final t in titik.skip(1)) {
      p.lineTo(t.dx, t.dy);
    }
    return p;
  }

  switch (moda) {
    case ModaPenanda.motor:
      k
        ..drawCircle(const Offset(5, 16.5), 3, garis)
        ..drawCircle(const Offset(19, 16.5), 3, garis)
        ..drawPath(
          jalur(const [
            Offset(5, 16.5),
            Offset(8, 16.5),
            Offset(10.5, 12.5),
            Offset(14.5, 12.5),
            Offset(15.5, 14.5),
            Offset(19, 14.5),
          ]),
          garis,
        )
        ..drawPath(
          jalur(const [
            Offset(10.5, 12.5),
            Offset(9, 9),
            Offset(12.5, 9),
            Offset(13.5, 10.5),
          ]),
          garis,
        )
        ..drawLine(const Offset(15, 9), const Offset(18, 9), garis);
    case ModaPenanda.mobil:
      k
        ..drawCircle(const Offset(6.5, 17), 2, garis)
        ..drawCircle(const Offset(17.5, 17), 2, garis)
        ..drawPath(
          jalur(const [
            Offset(3, 15),
            Offset(3, 12.5),
            Offset(5, 9),
            Offset(13, 9),
            Offset(16, 12.5),
            Offset(19, 12.5),
            Offset(21, 14),
            Offset(21, 15),
            Offset(18.5, 15),
          ]),
          garis,
        )
        ..drawLine(const Offset(8.5, 15), const Offset(15, 15), garis);
    case ModaPenanda.sepeda:
      k
        ..drawCircle(const Offset(5.5, 16), 3.5, garis)
        ..drawCircle(const Offset(18.5, 16), 3.5, garis)
        ..drawPath(
          jalur(const [
            Offset(5.5, 16),
            Offset(9, 10),
            Offset(15, 10),
            Offset(18.5, 16),
          ]),
          garis,
        )
        ..drawPath(
          jalur(const [Offset(9, 10), Offset(12, 16), Offset(15, 10)]),
          garis,
        )
        ..drawLine(const Offset(7.5, 8.5), const Offset(10.5, 8.5), garis)
        ..drawPath(
          jalur(const [Offset(15, 10), Offset(14.2, 7.5), Offset(16.2, 7.5)]),
          garis,
        );
    case ModaPenanda.jalanKaki:
      k
        ..drawCircle(const Offset(13, 4.5), 1.6, garis)
        ..drawPath(
          jalur(const [
            Offset(12, 8),
            Offset(9.5, 10),
            Offset(10.5, 14),
            Offset(8.5, 19.5),
          ]),
          garis,
        )
        ..drawPath(
          jalur(const [Offset(13, 10), Offset(16, 12), Offset(16.5, 15)]),
          garis,
        )
        ..drawLine(const Offset(11.5, 14), const Offset(14.5, 15), garis);
    case ModaPenanda.lainnya:
      k
        ..drawLine(const Offset(5, 12), const Offset(18, 12), garis)
        ..drawPath(
          jalur(const [Offset(13, 7), Offset(18, 12), Offset(13, 17)]),
          garis,
        );
  }
}

Color _warnaDariHex(String hex) {
  final bersih = hex.replaceAll('#', '');
  return Color(int.parse('FF$bersih', radix: 16));
}

/// Satu kendaraan yang sedang ditampilkan.
class _Penanda {
  _Penanda({
    required this.posisi,
    required this.moda,
    required this.warna,
    this.nama,
  }) : asal = posisi,
       tujuan = posisi;

  LatLng posisi;
  LatLng asal;
  LatLng tujuan;
  ModaPenanda moda;
  String warna;
  String? nama;

  /// Arah kompas terakhir yang diketahui. null sampai kendaraannya pernah
  /// benar-benar berpindah — menebak arah dari satu titik itu ngawur.
  double? arah;

  /// 0..1 selama meluncur ke [tujuan]; 1 berarti diam.
  double t = 1;

  /// Kapan luncuran terakhirnya dimulai. Per kendaraan, bukan bersama:
  /// posisi teman B yang masuk tidak boleh membuat motor A melompat.
  DateTime mulai = DateTime.now();
}

/// Kendaraan-kendaraan di satu sumber GeoJSON, yang meluncur saat posisinya
/// berubah.
///
/// Soal baterai: penghitung bingkai hanya hidup selama ada yang meluncur —
/// sekitar satu setengah detik per posisi baru, yang datang tiap belasan
/// detik. Di antaranya peta diam dan tidak ada yang diperbarui.
class LuncuranKendaraan {
  LuncuranKendaraan({required this.gambar});

  /// Dipanggil tiap bingkai dengan isi sumber GeoJSON terbaru.
  final Future<void> Function(Map<String, dynamic> isi) gambar;

  final _penanda = <String, _Penanda>{};
  Timer? _detak;

  /// Kombinasi ikon yang sedang dibutuhkan, untuk didaftarkan ke peta.
  Iterable<(ModaPenanda, String, bool)> get ikonDibutuhkan => _penanda.values
      .map((p) => (p.moda, p.warna, ArahTampil.dariArah(p.arah ?? 90).cermin));

  /// Letakkan atau pindahkan satu kendaraan.
  void atur(
    String id, {
    required LatLng posisi,
    required ModaPenanda moda,
    required String warna,
    String? nama,
  }) {
    final ada = _penanda[id];
    if (ada == null) {
      _penanda[id] = _Penanda(
        posisi: posisi,
        moda: moda,
        warna: warna,
        nama: nama,
      );
      unawaited(gambar(isiGeoJson()));
      return;
    }

    ada
      ..moda = moda
      ..warna = warna
      ..nama = nama;

    // Simpangan GPS di tempat parkir tidak boleh membuat motornya berputar
    // badan ke segala arah.
    if (jarakKasarM(ada.tujuan, posisi) >= 4) {
      ada.arah = arahKompas(ada.tujuan, posisi);
    }
    ada
      ..asal = ada.posisi
      ..tujuan = posisi
      ..t = 0
      ..mulai = DateTime.now();
    _detak ??= Timer.periodic(TourvellaMotion.bingkaiPeta, (_) => _bingkai());
  }

  /// Buang kendaraan yang tidak lagi ada di [yangAda].
  void sisakan(Set<String> yangAda) {
    final sebelum = _penanda.length;
    _penanda.removeWhere((id, _) => !yangAda.contains(id));
    if (_penanda.length != sebelum) unawaited(gambar(isiGeoJson()));
  }

  void _bingkai() {
    final sekarang = DateTime.now();
    var masihMeluncur = false;

    for (final p in _penanda.values) {
      if (p.t >= 1) continue;
      final t =
          (sekarang.difference(p.mulai).inMilliseconds /
                  TourvellaMotion.luncurKendaraan.inMilliseconds)
              .clamp(0.0, 1.0);
      final halus = TourvellaMotion.mengalir.transform(t);
      p
        ..t = t
        ..posisi = LatLng(
          p.asal.latitude + (p.tujuan.latitude - p.asal.latitude) * halus,
          p.asal.longitude + (p.tujuan.longitude - p.asal.longitude) * halus,
        );
      if (t < 1) masihMeluncur = true;
    }

    unawaited(gambar(isiGeoJson()));

    if (!masihMeluncur) {
      _detak?.cancel();
      _detak = null;
    }
  }

  Map<String, dynamic> isiGeoJson() => {
    'type': 'FeatureCollection',
    'features': [
      for (final e in _penanda.entries)
        () {
          final arah = ArahTampil.dariArah(e.value.arah ?? 90);
          return {
            'type': 'Feature',
            'id': e.key,
            'properties': {
              'ikon': namaIkonKendaraan(e.value.moda, e.value.warna, arah.cermin),
              'putar': arah.putar,
              // Riak yang melebar lalu hilang sekali tiap posisi baru.
              'riak': e.value.t,
              'warna': e.value.warna,
              'nama': e.value.nama ?? '',
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [
                e.value.posisi.longitude,
                e.value.posisi.latitude,
              ],
            },
          };
        }(),
    ],
  };

  void dispose() {
    _detak?.cancel();
    _detak = null;
  }
}
