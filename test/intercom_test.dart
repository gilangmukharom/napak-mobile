import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tourvella/features/intercom/data/olah_suara.dart';
import 'package:tourvella/features/trips/presentation/penanda_kendaraan.dart';

Int16List nada(double amplitudo, {int panjang = sampelPerPotongan}) =>
    Int16List.fromList([
      for (var i = 0; i < panjang; i++)
        (amplitudo * math.sin(2 * math.pi * 440 * i / lajuSampel)).round(),
    ]);

void main() {
  group('μ-law', () {
    test('bolak-balik cukup dekat dengan aslinya', () {
      final asli = nada(12000);
      final balik = dariMulaw(keMulaw(asli));
      for (var i = 0; i < asli.length; i++) {
        // G.711 kehilangan paling banyak ~3% di amplitudo ini.
        expect((balik[i] - asli[i]).abs(), lessThan(asli[i].abs() * 0.04 + 40));
      }
    });

    test('separuh ukuran PCM', () {
      expect(keMulaw(nada(1000)).lengthInBytes, sampelPerPotongan);
    });

    test('nilai ekstrem tidak meluap', () {
      final balik = dariMulaw(keMulaw(Int16List.fromList([-32768, 32767, 0])));
      expect(balik[0], lessThan(-30000));
      expect(balik[1], greaterThan(30000));
      expect(balik[2].abs(), lessThan(10));
    });
  });

  test('pemotong merapikan potongan mikrofon yang tidak beraturan', () {
    final pemotong = PemotongPcm();
    final byte = Uint8List(sampelPerPotongan * 2 * 3 + 100);
    final hasil = [
      ...pemotong.masukkan(Uint8List.sublistView(byte, 0, 777)),
      ...pemotong.masukkan(Uint8List.sublistView(byte, 777)),
    ];
    expect(hasil, hasLength(3));
    expect(hasil.every((p) => p.length == sampelPerPotongan), isTrue);
  });

  group('pendeteksi suara', () {
    test('diam tidak dikirim, bicara dikirim bersama awalannya', () {
      final vad = PendeteksiSuara();
      for (var i = 0; i < 20; i++) {
        expect(vad.saring(nada(80)), isEmpty);
      }
      // Potongan diam terakhir ikut sebagai awalan: suku kata pertama utuh.
      expect(vad.saring(nada(6000)), hasLength(2));
      expect(vad.saring(nada(6000)), hasLength(1));
    });

    test('ekor kata tidak terpotong, lalu berhenti', () {
      final vad = PendeteksiSuara();
      vad.saring(nada(6000));
      var terkirim = 0;
      for (var i = 0; i < 30; i++) {
        terkirim += vad.saring(nada(80)).length;
      }
      expect(terkirim, 10);
    });
  });

  group('pencampur', () {
    test('menunggu tiga potongan sebelum memutar', () {
      final c = PencampurSuara();
      c.terima('a', nada(1000));
      c.terima('a', nada(1000));
      expect(PendeteksiSuara.rmsDari(c.ambil()), 0);
      c.terima('a', nada(1000));
      expect(PendeteksiSuara.rmsDari(c.ambil()), greaterThan(500));
    });

    test('dua orang bicara bersamaan tidak meluap', () {
      final c = PencampurSuara();
      for (var i = 0; i < 3; i++) {
        c.terima('a', nada(30000));
        c.terima('b', nada(30000));
      }
      final hasil = c.ambil();
      expect(hasil.reduce(math.max), 32767);
      expect(hasil.reduce(math.min), -32768);
    });

    test('antrean yang tertinggal jauh dibuang, bukan diputar telat', () {
      final c = PencampurSuara();
      for (var i = 0; i < 50; i++) {
        c.terima('a', nada(1000));
      }
      var diputar = 0;
      while (PendeteksiSuara.rmsDari(c.ambil()) > 0) {
        diputar++;
      }
      expect(diputar, 12);
    });

    test('yang bicara ditandai sebentar saja', () {
      final c = PencampurSuara();
      final t = DateTime(2026, 9, 22, 8);
      c.terima('a', nada(1000), pada: t);
      expect(c.yangBicara(sekarang: t.add(const Duration(milliseconds: 200))), {'a'});
      expect(c.yangBicara(sekarang: t.add(const Duration(seconds: 2))), isEmpty);
    });
  });

  group('arah kendaraan di peta', () {
    test('ke timur: apa adanya', () {
      final a = ArahTampil.dariArah(90);
      expect(a.cermin, isFalse);
      expect(a.putar, 0);
    });

    test('ke barat: dicerminkan, tidak jungkir balik', () {
      final a = ArahTampil.dariArah(270);
      expect(a.cermin, isTrue);
      expect(a.putar, 0);
    });

    test('ke utara dan selatan: diputar, tidak dicerminkan', () {
      expect(ArahTampil.dariArah(0).putar, -90);
      expect(ArahTampil.dariArah(180).putar, 90);
      expect(ArahTampil.dariArah(0).cermin, isFalse);
    });

    test('ke barat laut: dicerminkan lalu miring ke atas', () {
      final a = ArahTampil.dariArah(315);
      expect(a.cermin, isTrue);
      expect(a.putar, 45);
    });

    test('arah kompas Jakarta → Bandung kira-kira tenggara', () {
      final arah = arahKompas(
        const LatLng(-6.2, 106.8),
        const LatLng(-6.9, 107.6),
      );
      expect(arah, inInclusiveRange(125, 145));
    });

    test('nama ikon memisahkan warna dan arah', () {
      expect(
        namaIkonKendaraan(ModaPenanda.motor, '#5C87B0', true),
        'kendaraan-motor-5c87b0-c',
      );
      expect(ModaPenanda.dari('kapal'), ModaPenanda.lainnya);
      expect(ModaPenanda.dari(null), ModaPenanda.lainnya);
    });
  });
}
