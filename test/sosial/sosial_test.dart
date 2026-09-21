import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:napak/features/obrolan/data/obrolan_data.dart';
import 'package:napak/features/sosial/data/sosial_models.dart';
import 'package:napak/features/sosial/presentation/komponen_sosial.dart';
import 'package:napak/features/trips/data/trip_models.dart';

String _token(Map<String, dynamic> muatan) {
  String bagian(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${bagian({'alg': 'HS256'})}.${bagian(muatan)}.tandatangan';
}

void main() {
  group('id dari token', () {
    test('mengambil sub', () {
      expect(idDariToken(_token({'sub': 'abc-123', 'name': 'Rina'})), 'abc-123');
    });

    test('nama berhuruf non-ASCII tidak merusak pembacaan', () {
      expect(idDariToken(_token({'sub': 'x', 'name': 'Sârî Wulandari'})), 'x');
    });

    test('token rusak dijawab null, bukan melempar', () {
      expect(idDariToken('bukan.token'), isNull);
      expect(idDariToken('a.%%%.c'), isNull);
      expect(idDariToken(null), isNull);
    });
  });

  group('waktu santai', () {
    final kini = DateTime(2026, 9, 21, 14, 0);

    test('baru saja, menit, jam', () {
      expect(waktuSantai(kini.subtract(const Duration(seconds: 20)), sekarang: kini), 'baru saja');
      expect(waktuSantai(kini.subtract(const Duration(minutes: 5)), sekarang: kini), '5 mnt');
      expect(waktuSantai(kini.subtract(const Duration(hours: 3)), sekarang: kini), '3 jam');
    });

    test('kemarin tetap kemarin walau kurang dari 24 jam', () {
      // Jam 23 kemarin, dilihat jam 14 hari ini: 15 jam lalu, tapi orang
      // menyebutnya "kemarin", bukan "15 jam".
      expect(waktuSantai(DateTime(2026, 9, 20, 23), sekarang: kini), 'kemarin');
    });

    test('tanggal Indonesia, tahun hanya kalau beda', () {
      expect(waktuSantai(DateTime(2026, 8, 17), sekarang: kini), '17 Agu');
      expect(waktuSantai(DateTime(2025, 12, 31), sekarang: kini), '31 Des 2025');
    });
  });

  group('kabar', () {
    test('jenis yang belum dikenal tidak membuat inbox gagal dibaca', () {
      final k = Kabar.fromJson({
        'id': '1',
        'jenis': 'jenis_masa_depan',
        'judul': 'x',
        'isi': 'y',
        'sudahDibaca': false,
        'createdAt': '2026-09-21T07:00:00Z',
      });
      expect(k.jenis, JenisKabar.lain);
    });
  });

  group('konvoi', () {
    test('membaca kabar dari server', () {
      final k = KabarKonvoi.fromJson({
        'barisan': [
          {'userId': 'a', 'nama': 'Andi', 'urutan': 1, 'selisihM': 0, 'tertinggal': false, 'hilangKontak': false},
          {'userId': 'b', 'nama': 'Budi', 'urutan': 2, 'selisihM': 2400, 'tertinggal': true, 'hilangKontak': false},
        ],
        'rentangM': 2400,
        'pengumuman': [
          {'userId': 'b', 'nama': 'Budi', 'selisihM': 2400, 'pesan': 'Budi tertinggal 2,4 km di belakang.'},
        ],
      });

      expect(k.barisan, hasLength(2));
      expect(k.barisan[1].tertinggal, isTrue);
      expect(k.pengumuman.single, contains('2,4 km'));
    });
  });

  group('jejak nusantara', () {
    test('porsi provinsi tanpa kota tidak membagi dengan nol', () {
      const p = ProvinsiTerjejak(nama: 'X', kota: [], totalKota: 0);
      expect(p.porsi, 0);
    });
  });
}
