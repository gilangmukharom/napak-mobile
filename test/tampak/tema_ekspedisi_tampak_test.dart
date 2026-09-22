import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourvella/core/theme/tourvella_colors.dart';
import 'package:tourvella/core/theme/tourvella_tekstur.dart';
import 'package:tourvella/core/theme/tourvella_theme.dart';
import 'package:tourvella/core/widgets/tourvella_ekspedisi.dart';

/// Contoh tampak tema ekspedisi, dipakai untuk melihat hasilnya dengan mata.
///
/// Dijalankan dengan:
///
/// ```
/// TOURVELLA_TAMPAK=1 flutter test --update-goldens test/tampak
/// ```
///
/// lalu `test/tampak/tema_ekspedisi.png` dibuka. Bukan tes regresi piksel —
/// perbandingan piksel antar mesin gampang gagal karena beda render font,
/// jadi tanpa `TOURVELLA_TAMPAK` ia dilewati dan CI tidak pernah menjalankannya.
/// Gunanya cuma satu: memastikan kontur, punggungan gunung, dan butiran
/// memang tergambar, bukan sekadar lolos analisis statis.
void main() {
  testWidgets(
    'tampak tema ekspedisi',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: TourvellaTheme.gelap(),
          home: Scaffold(
            appBar: const BilahEkspedisi(
              judul: 'Jejakmu',
              keterangan: '12 perjalanan',
            ),
            body: LatarEkspedisi(
              gunung: true,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelKapital(
                      'Ditempuh',
                      warna: TourvellaColors.emberRedup,
                    ),
                    const Odometer(
                      nilai: 1284.6,
                      desimal: 1,
                      satuan: 'KM',
                      gaya: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: TourvellaColors.ember,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const PemisahJalur(warna: TourvellaColors.kontur),
                    const SizedBox(height: 24),
                    Row(
                      children: const [
                        StempelPencapaian(
                          teks: '14 provinsi',
                          keterangan: 'terjejak',
                        ),
                        SizedBox(width: 18),
                        StempelPencapaian(
                          teks: 'Sejak 2024',
                          keterangan: 'menjejak',
                          miring: 0.05,
                        ),
                        Spacer(),
                        JarumKompas(arah: -22, ukuran: 64),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Mulai merekam'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Jarum kompasnya bergoyang terus, jadi halaman ini tidak pernah
      // "settle". Cukup maju sampai animasi masuknya selesai.
      await tester.pump(const Duration(milliseconds: 1400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('tema_ekspedisi.png'),
      );
    },
    skip: !Platform.environment.containsKey('TOURVELLA_TAMPAK'),
  );
}
