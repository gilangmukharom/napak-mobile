import 'dart:math' as math;

import '../data/navigasi_data.dart';

/// Di mana kamu berada di sepanjang rute, dan apa manuver berikutnya.
class KeadaanNavigasi {
  const KeadaanNavigasi({
    required this.indeksLangkah,
    required this.jarakKeManuverM,
    required this.sisaJarakM,
    required this.jarakDariRuteM,
    required this.sampai,
  });

  /// Langkah yang sedang dituju.
  final int indeksLangkah;

  /// Jarak **menyusuri rute** sampai manuver berikutnya, bukan garis lurus —
  /// di jalan berkelok, garis lurus bisa setengahnya saja, dan suara
  /// "belok 200 meter lagi" jadi terlambat.
  final double jarakKeManuverM;
  final double sisaJarakM;

  /// Seberapa jauh dari garis rute. Dipakai menandai keluar jalur.
  final double jarakDariRuteM;
  final bool sampai;
}

/// Jarak dari rute yang masih dianggap "masih di jalur".
///
/// 60 m, bukan 20: simpangan GPS di antara gedung tinggi biasa 15–30 m, dan
/// jalan tol punya dua arah terpisah yang jaraknya belasan meter. Terlalu
/// ketat berarti aplikasinya menghitung ulang rute terus-menerus padahal
/// orangnya jalan lurus saja.
const double ambangKeluarJalurM = 60;

/// Penjejak posisi di sepanjang satu rute.
///
/// Semua perhitungannya memakai **jarak sepanjang garis rute**, bukan garis
/// lurus. Panjang tiap ruas dihitung sekali di awal, jadi tiap pembaruan
/// posisi cuma menelusuri ruas terdekat.
class PenjejakRute {
  PenjejakRute(this.rute)
    : _kumulatif = _hitungKumulatif(rute.garis),
      _titik = rute.garis {
    _langkahKumulatif = [
      for (final l in rute.langkah)
        _proyeksiKumulatif((lat: l.lat, lng: l.lng)).kumulatif,
    ];
  }

  final Rute rute;
  final List<({double lat, double lng})> _titik;
  final List<double> _kumulatif;
  late final List<double> _langkahKumulatif;

  double get panjangM => _kumulatif.isEmpty ? 0 : _kumulatif.last;

  /// Satu pembaruan posisi.
  KeadaanNavigasi perbarui(double lat, double lng, {int? dariLangkah}) {
    final di = _proyeksiKumulatif((lat: lat, lng: lng));

    // Langkah berikutnya: yang manuvernya masih di depan. Langkah yang
    // terlewat (sudah di belakang) tidak pernah diumumkan lagi.
    var indeks = dariLangkah ?? 0;
    while (indeks < _langkahKumulatif.length - 1 &&
        _langkahKumulatif[indeks] <= di.kumulatif + 5) {
      indeks++;
    }

    final keManuver = math.max(0.0, _langkahKumulatif[indeks] - di.kumulatif);
    final sisa = math.max(0.0, panjangM - di.kumulatif);

    return KeadaanNavigasi(
      indeksLangkah: indeks,
      jarakKeManuverM: keManuver,
      sisaJarakM: sisa,
      jarakDariRuteM: di.jarak,
      // Sampai: sisa rutenya habis dan memang dekat dengan garisnya.
      sampai: sisa < 30 && di.jarak < 60,
    );
  }

  /// Titik terdekat di rute: berapa meter dari sana, dan sudah sejauh apa
  /// titik itu di sepanjang rute.
  ({double jarak, double kumulatif}) _proyeksiKumulatif(
    ({double lat, double lng}) posisi,
  ) {
    var terbaikJarak = double.infinity;
    var terbaikKumulatif = 0.0;

    for (var i = 0; i < _titik.length - 1; i++) {
      final hasil = _keRuas(posisi, _titik[i], _titik[i + 1]);
      if (hasil.jarak < terbaikJarak) {
        terbaikJarak = hasil.jarak;
        terbaikKumulatif = _kumulatif[i] + hasil.majuM;
      }
    }

    if (_titik.length == 1) {
      return (jarak: jarakMeter(posisi, _titik.first), kumulatif: 0);
    }
    return (jarak: terbaikJarak, kumulatif: terbaikKumulatif);
  }

  static List<double> _hitungKumulatif(
    List<({double lat, double lng})> titik,
  ) {
    final hasil = <double>[0];
    for (var i = 1; i < titik.length; i++) {
      hasil.add(hasil[i - 1] + jarakMeter(titik[i - 1], titik[i]));
    }
    return hasil;
  }

  /// Jarak titik ke satu ruas garis, dan sejauh mana proyeksinya di ruas itu.
  static ({double jarak, double majuM}) _keRuas(
    ({double lat, double lng}) p,
    ({double lat, double lng}) a,
    ({double lat, double lng}) b,
  ) {
    // Di jarak ratusan meter, bumi cukup datar: lintang/bujur diubah ke meter
    // sekali, lalu semuanya aljabar biasa.
    final skalaLng = math.cos(a.lat * math.pi / 180);
    double x(({double lat, double lng}) t) => (t.lng - a.lng) * skalaLng * 111320;
    double y(({double lat, double lng}) t) => (t.lat - a.lat) * 110540;

    final bx = x(b), by = y(b);
    final px = x(p), py = y(p);
    final panjang2 = bx * bx + by * by;
    if (panjang2 == 0) {
      return (jarak: math.sqrt(px * px + py * py), majuM: 0);
    }

    final t = ((px * bx + py * by) / panjang2).clamp(0.0, 1.0);
    final dx = px - bx * t;
    final dy = py - by * t;
    return (
      jarak: math.sqrt(dx * dx + dy * dy),
      majuM: t * math.sqrt(panjang2),
    );
  }
}

double jarakMeter(
  ({double lat, double lng}) a,
  ({double lat, double lng}) b,
) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final s =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(s));
}

/// Ambang pengumuman suara untuk satu manuver, dari jauh ke dekat.
///
/// Empat kali, bukan terus-menerus: suara yang berbunyi tiap sepuluh detik
/// membuat orang mematikannya, dan navigasi yang dimatikan tidak menolong
/// siapa pun.
const List<double> ambangSuaraM = [1000, 400, 120, 25];

/// Ambang mana yang baru saja dilewati, atau null kalau belum ada yang baru.
///
/// [sudah] berisi ambang yang sudah diumumkan untuk langkah ini.
double? ambangBaru(double jarakM, Set<double> sudah, {double? jarakLangkah}) {
  for (final a in ambangSuaraM) {
    if (sudah.contains(a)) continue;
    // Tidak mengumumkan "1 kilometer lagi" untuk belokan yang memang cuma
    // 300 m dari belokan sebelumnya — itu terdengar seperti mengulang.
    if (jarakLangkah != null && jarakLangkah < a * 1.2) {
      sudah.add(a);
      continue;
    }
    if (jarakM <= a) return a;
  }
  return null;
}
