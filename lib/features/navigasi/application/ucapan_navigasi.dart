import 'package:flutter/material.dart';

import '../data/navigasi_data.dart';

/// Kalimat dan ikon navigasi di HP.
///
/// Kalimatnya disusun di sini, bukan diambil apa adanya dari server, karena
/// **jaraknya berubah tiap beberapa detik**: "satu kilometer lagi" berubah
/// jadi "400 meter lagi" lalu "belok kiri sekarang" untuk manuver yang sama.
/// Server hanya mengirim manuvernya (belok apa, ke jalan mana) dan kalimat
/// pembuka sekali di awal.
///
/// Pasangannya di backend: `instruksi-rute.ts`. Kalau salah satu diubah,
/// ubah dua-duanya — ada tes yang menjaga bunyinya tetap sama.

const _belok = <String, String>{
  'kiri': 'Belok kiri',
  'kanan': 'Belok kanan',
  'kiri-tajam': 'Belok tajam ke kiri',
  'kanan-tajam': 'Belok tajam ke kanan',
  'kiri-landai': 'Serong kiri',
  'kanan-landai': 'Serong kanan',
  'lurus': 'Terus lurus',
  'balik': 'Putar balik',
};

/// Nama jalan yang kepanjangan lebih membingungkan daripada membantu.
const _jalanMaks = 34;

String _keJalan(String? nama) {
  final bersih = (nama ?? '').trim();
  if (bersih.isEmpty || bersih.length > _jalanMaks) return '';
  return ' ke $bersih';
}

String _diJalan(String? nama) {
  final bersih = (nama ?? '').trim();
  if (bersih.isEmpty || bersih.length > _jalanMaks) return '';
  return ' di $bersih';
}

/// Tindakannya saja, tanpa jarak. Dipakai juga sebagai tulisan besar di panel.
String kalimatManuver(LangkahRute l) {
  switch (l.jenis) {
    case 'berangkat':
      return 'Berangkat${_diJalan(l.jalan)}';
    case 'sampai':
      return 'Sampai di tujuan';
    case 'putar-balik':
      return 'Putar balik${_keJalan(l.jalan)}';
    case 'bundaran':
      return 'Ikuti bundaran${_keJalan(l.jalan)}';
    case 'keluar-tol':
      return 'Ambil pintu keluar${_keJalan(l.jalan)}';
    case 'masuk-tol':
      return 'Masuk tol${_keJalan(l.jalan)}';
    case 'gabung':
      return 'Bergabung${_keJalan(l.jalan)}';
    case 'ambil':
      return l.arah == 'lurus'
          ? 'Ambil jalur lurus${_keJalan(l.jalan)}'
          : 'Ambil jalur ${l.arah.startsWith('kiri') ? 'kiri' : 'kanan'}${_keJalan(l.jalan)}';
    case 'lurus':
      return 'Terus lurus${_diJalan(l.jalan)}';
    default:
      return l.arah == 'lurus'
          ? 'Terus lurus${_diJalan(l.jalan)}'
          : '${_belok[l.arah] ?? 'Belok'}${_keJalan(l.jalan)}';
  }
}

/// Jarak seperti orang menyebutnya, bukan seperti mesin.
String jarakDiucapkan(double meter) {
  if (meter < 20) return 'sekarang';
  if (meter < 100) return '${(meter / 10).round() * 10} meter lagi';
  if (meter < 1000) return '${(meter / 50).round() * 50} meter lagi';
  final km = meter / 1000;
  if (km < 10) {
    final angka = '${(km * 10).round() / 10}'.replaceAll('.', ',');
    return '$angka kilometer lagi';
  }
  return '${km.round()} kilometer lagi';
}

/// Jarak pendek untuk dibaca sekilas di panel: "350 m", "12,4 km".
String jarakSingkat(double meter) {
  if (meter < 1000) return '${(meter / 10).round() * 10} m';
  final km = meter / 1000;
  if (km < 10) {
    final angka = '${(km * 10).round() / 10}'.replaceAll('.', ',');
    return '$angka km';
  }
  return '${km.round()} km';
}

/// Kalimat lengkap yang dibacakan: jarak dulu, baru tindakannya.
String kalimatNavigasi(LangkahRute l, double meter) {
  final tindakan = kalimatManuver(l);
  if (l.jenis == 'berangkat') return tindakan;
  if (l.jenis == 'sampai') {
    return meter < 30
        ? 'Sampai di tujuan'
        : '${jarakDiucapkan(meter)}, sampai di tujuan';
  }
  final jarak = jarakDiucapkan(meter);
  if (jarak == 'sekarang') return '$tindakan sekarang';
  // Huruf pertamanya saja yang dikecilkan — "Jalan Kaliurang" tetap nama
  // jalan.
  return '$jarak, ${tindakan[0].toLowerCase()}${tindakan.substring(1)}';
}

/// Panah besar di panel navigasi.
IconData ikonManuver(LangkahRute l) {
  switch (l.jenis) {
    case 'sampai':
      return Icons.flag_rounded;
    case 'berangkat':
      return Icons.navigation_rounded;
    case 'bundaran':
      return Icons.roundabout_right_rounded;
    case 'putar-balik':
      return Icons.u_turn_left_rounded;
    case 'masuk-tol':
      return Icons.ramp_right_rounded;
    case 'keluar-tol':
      return Icons.exit_to_app_rounded;
    case 'gabung':
      return Icons.merge_rounded;
    default:
      return switch (l.arah) {
        'kiri' => Icons.turn_left_rounded,
        'kanan' => Icons.turn_right_rounded,
        'kiri-tajam' => Icons.turn_sharp_left_rounded,
        'kanan-tajam' => Icons.turn_sharp_right_rounded,
        'kiri-landai' => Icons.turn_slight_left_rounded,
        'kanan-landai' => Icons.turn_slight_right_rounded,
        'balik' => Icons.u_turn_left_rounded,
        _ => Icons.straight_rounded,
      };
  }
}
