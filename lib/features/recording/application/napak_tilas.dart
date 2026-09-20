import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../trips/data/trip_models.dart';

/// Satu titik perjalanan lama, sudah disiapkan untuk dibandingkan.
@immutable
class JejakLama {
  const JejakLama({
    required this.lat,
    required this.lng,
    required this.sejakBerangkat,
    required this.jarakTempuhM,
    this.catatan,
  });

  final double lat;
  final double lng;

  /// Berapa lama setelah berangkat titik ini direkam.
  final Duration sejakBerangkat;

  /// Jarak kumulatif dari titik berangkat sampai titik ini.
  final double jarakTempuhM;

  final String? catatan;
}

/// Bagaimana perjalanan sekarang dibanding yang dulu.
@immutable
class PerbandinganTilas {
  const PerbandinganTilas({
    required this.posisiDulu,
    required this.selisih,
    required this.jarakDuluM,
    this.catatanTerdekat,
  });

  /// Di mana kamu berada pada titik waktu yang sama, dulu.
  final ({double lat, double lng})? posisiDulu;

  /// Positif berarti sekarang lebih cepat; negatif berarti lebih lambat.
  ///
  /// null saat belum bisa dibandingkan — misalnya baru berangkat dan jarak
  /// tempuhnya masih nol.
  final Duration? selisih;

  /// Sudah sejauh apa kamu dulu pada titik waktu yang sama.
  final double jarakDuluM;

  /// Catatan dari perjalanan dulu yang lokasinya paling dekat dengan posisimu
  /// sekarang — "dulu di sini kamu berhenti makan soto".
  final String? catatanTerdekat;
}

/// Menyiapkan perjalanan lama untuk ditapak-tilasi.
///
/// Dihitung sekali saat perjalanan dimulai, bukan berulang tiap titik GPS
/// masuk. Rute mudik enam jam berisi ratusan titik; menghitung ulang jarak
/// kumulatifnya tiap tiga puluh detik adalah pekerjaan yang sama, berkali-kali,
/// untuk hasil yang sama.
List<JejakLama> siapkanJejakLama(List<TripPoint> titik) {
  if (titik.isEmpty) return const [];

  final berangkat = titik.first.recordedAt;
  final hasil = <JejakLama>[];
  var jarak = 0.0;

  for (var i = 0; i < titik.length; i++) {
    if (i > 0) {
      jarak += _haversineMeter(
        titik[i - 1].lat,
        titik[i - 1].lng,
        titik[i].lat,
        titik[i].lng,
      );
    }

    hasil.add(
      JejakLama(
        lat: titik[i].lat,
        lng: titik[i].lng,
        sejakBerangkat: titik[i].recordedAt.difference(berangkat),
        jarakTempuhM: jarak,
        catatan: titik[i].note,
      ),
    );
  }

  return hasil;
}

/// Membandingkan perjalanan sekarang dengan yang dulu.
///
/// Selisihnya dihitung dari **jarak**, bukan dari waktu: dicari dulu kapan
/// perjalanan lama mencapai jarak yang sudah kamu tempuh sekarang, lalu
/// dibandingkan dengan berapa lama kamu menempuhnya.
///
/// Membandingkan lewat waktu ("dulu jam segini kamu sudah di mana") terdengar
/// lebih mudah, tapi jadi menyesatkan begitu ada yang berhenti lama: berhenti
/// makan satu jam membuatmu terlihat "tertinggal jauh" padahal jalannya
/// sama-sama saja.
PerbandinganTilas bandingkan({
  required List<JejakLama> lama,
  required Duration sudahBerjalan,
  required double jarakSekarangM,
  ({double lat, double lng})? posisiSekarang,
}) {
  if (lama.isEmpty) {
    return const PerbandinganTilas(
      posisiDulu: null,
      selisih: null,
      jarakDuluM: 0,
    );
  }

  // Di mana kamu dulu pada lama perjalanan yang sama.
  final duluSaatIni = _padaWaktu(lama, sudahBerjalan);

  // Dulu, butuh berapa lama untuk sampai sejauh ini?
  final Duration? dulunyaButuh = jarakSekarangM <= 0
      ? null
      : _waktuSampaiJarak(lama, jarakSekarangM);

  return PerbandinganTilas(
    posisiDulu: duluSaatIni == null
        ? null
        : (lat: duluSaatIni.lat, lng: duluSaatIni.lng),
    selisih: dulunyaButuh == null ? null : dulunyaButuh - sudahBerjalan,
    jarakDuluM: duluSaatIni?.jarakTempuhM ?? 0,
    catatanTerdekat: posisiSekarang == null
        ? null
        : _catatanTerdekat(lama, posisiSekarang),
  );
}

/// Kalimat perbandingan dalam Bahasa Indonesia.
///
/// Selisih di bawah dua menit dianggap sama saja. Mengatakan "kamu 40 detik
/// lebih cepat" itu ketelitian palsu — simpangan GPS sendiri sudah sebesar
/// itu, dan tidak ada yang merasakan bedanya.
String kalimatSelisih(Duration? selisih) {
  if (selisih == null) return 'Baru berangkat.';

  final menit = selisih.inMinutes;
  if (menit.abs() < 2) return 'Persis seperti dulu.';

  final besaran = menit.abs() >= 60
      ? '${(menit.abs() / 60).toStringAsFixed(1)} jam'
      : '${menit.abs()} menit';

  return menit > 0
      ? '$besaran lebih cepat dari dulu.'
      : '$besaran lebih lambat dari dulu.';
}

/// Posisi pada lama perjalanan tertentu, diinterpolasi di antara dua titik.
JejakLama? _padaWaktu(List<JejakLama> lama, Duration sejak) {
  if (sejak <= lama.first.sejakBerangkat) return lama.first;
  if (sejak >= lama.last.sejakBerangkat) return lama.last;

  for (var i = 1; i < lama.length; i++) {
    if (lama[i].sejakBerangkat < sejak) continue;

    final a = lama[i - 1];
    final b = lama[i];
    final rentang =
        b.sejakBerangkat.inMilliseconds - a.sejakBerangkat.inMilliseconds;
    if (rentang <= 0) return b;

    final t =
        (sejak.inMilliseconds - a.sejakBerangkat.inMilliseconds) / rentang;

    return JejakLama(
      lat: a.lat + (b.lat - a.lat) * t,
      lng: a.lng + (b.lng - a.lng) * t,
      sejakBerangkat: sejak,
      jarakTempuhM: a.jarakTempuhM + (b.jarakTempuhM - a.jarakTempuhM) * t,
      catatan: null,
    );
  }

  return lama.last;
}

/// Dulu, butuh berapa lama untuk menempuh jarak sejauh ini?
Duration? _waktuSampaiJarak(List<JejakLama> lama, double jarakM) {
  if (jarakM > lama.last.jarakTempuhM) {
    // Sudah lebih jauh daripada seluruh perjalanan dulu; tidak ada lagi yang
    // bisa dibandingkan dengan jujur.
    return null;
  }

  for (var i = 1; i < lama.length; i++) {
    if (lama[i].jarakTempuhM < jarakM) continue;

    final a = lama[i - 1];
    final b = lama[i];
    final rentang = b.jarakTempuhM - a.jarakTempuhM;
    if (rentang <= 0) return b.sejakBerangkat;

    final t = (jarakM - a.jarakTempuhM) / rentang;
    final ms =
        a.sejakBerangkat.inMilliseconds +
        (b.sejakBerangkat.inMilliseconds - a.sejakBerangkat.inMilliseconds) * t;

    return Duration(milliseconds: ms.round());
  }

  return lama.last.sejakBerangkat;
}

/// Catatan lama yang lokasinya paling dekat, kalau memang cukup dekat.
String? _catatanTerdekat(
  List<JejakLama> lama,
  ({double lat, double lng}) posisi,
) {
  const ambangMeter = 400.0;

  String? terdekat;
  var jarakTerdekat = ambangMeter;

  for (final t in lama) {
    if (t.catatan == null) continue;
    final jarak = _haversineMeter(posisi.lat, posisi.lng, t.lat, t.lng);
    if (jarak < jarakTerdekat) {
      jarakTerdekat = jarak;
      terdekat = t.catatan;
    }
  }

  return terdekat;
}

const _jariBumiM = 6371008.8;

double _haversineMeter(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;

  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  return 2 * _jariBumiM * math.asin(math.min(1, math.sqrt(h)));
}
