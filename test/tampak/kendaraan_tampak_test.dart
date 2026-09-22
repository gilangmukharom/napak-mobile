import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourvella/features/trips/presentation/penanda_kendaraan.dart';

/// Penanda kendaraan di peta, untuk dilihat dengan mata:
///
///   TOURVELLA_TAMPAK=1 flutter test test/tampak/kendaraan_tampak_test.dart
///
/// lalu buka `test/tampak/kendaraan.png`. Baris atas menuju timur, baris
/// bawah menuju barat (dicerminkan).
void main() {
  testWidgets(
    'penanda kendaraan',
    (tester) async {
      await tester.runAsync(() async {
        const skala = 3.0;
        const petak = ukuranPenanda * skala;
        final moda = ModaPenanda.pilihan;
        final perekam = ui.PictureRecorder();
        final kanvas = Canvas(perekam)
          ..drawRect(
            Rect.fromLTWH(0, 0, petak * moda.length, petak * 2),
            Paint()..color = const Color(0xFFE2ECF4),
          );

        for (final (i, m) in moda.indexed) {
          for (final (baris, cermin) in [(0, false), (1, true)]) {
            final png = await gambarPenandaKendaraan(
              moda: m,
              warna: baris == 0 ? '#5C87B0' : '#D98A4E',
              cermin: cermin,
              rasioPiksel: skala,
            );
            final codec = await ui.instantiateImageCodec(png);
            final gambar = (await codec.getNextFrame()).image;
            kanvas.drawImage(gambar, Offset(i * petak, baris * petak), Paint());
          }
        }

        final hasil = await perekam.endRecording().toImage(
          (petak * moda.length).round(),
          (petak * 2).round(),
        );
        final data = await hasil.toByteData(format: ui.ImageByteFormat.png);
        File('test/tampak/kendaraan.png').writeAsBytesSync(
          data!.buffer.asUint8List(),
        );
      });
    },
    skip: !Platform.environment.containsKey('TOURVELLA_TAMPAK'),
  );
}
