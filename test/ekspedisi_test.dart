import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:napak/core/theme/napak_colors.dart';
import 'package:napak/core/theme/napak_theme.dart';
import 'package:napak/core/widgets/napak_ekspedisi.dart';

/// Tema Ekspedisi: warna bara, kanvas malam, dan komponen yang memakainya.
///
/// Yang dijaga di sini bukan selera, tapi dua hal yang gampang rusak diam-diam:
/// bilah judul yang tingginya tidak cocok dengan isinya (meluber sepersekian
/// piksel di ponsel tertentu, tanpa pernah terlihat di layar pengembang), dan
/// teks gelap yang tanpa sengaja dipakai di atas kanvas malam.
void main() {
  group('BilahEkspedisi', () {
    testWidgets('tingginya cukup untuk judul dan keterangannya', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: BilahEkspedisi(
              judul: 'Kotak pos',
              keterangan: 'Kabar dari jalan',
            ),
            body: SizedBox.shrink(),
          ),
        ),
      );

      // Satu luapan tata letak saja sudah membuat tes ini gagal.
      expect(tester.takeException(), isNull);
      expect(find.text('Kotak pos'), findsOneWidget);
      expect(find.text('KABAR DARI JALAN'), findsOneWidget);
    });

    testWidgets('tanpa keterangan tetap muat', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: BilahEkspedisi(judul: 'Teman'),
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Teman'), findsOneWidget);
    });
  });

  group('Odometer', () {
    testWidgets('angka berganti tanpa membuang satuannya', (tester) async {
      Widget bungkus(double nilai) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Odometer(nilai: nilai, desimal: 1, satuan: 'KM'),
          ),
        ),
      );

      await tester.pumpWidget(bungkus(12.4));
      expect(find.text('KM'), findsOneWidget);

      // Digit yang berubah berganti sambil berputar; yang tidak berubah
      // harus tetap diam, jadi angkanya tidak "bergetar" seluruhnya.
      await tester.pumpWidget(bungkus(12.9));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('KM'), findsOneWidget);
    });
  });

  group('palet ekspedisi', () {
    test('bara cukup jauh dari biru pastel untuk terbaca sebagai aksen', () {
      // Kalau suatu saat ada yang "menenangkan" bara sampai mendekati palet
      // pastel, ia berhenti menunjuk apa pun — dan itulah justru keluhan
      // yang melahirkan tema ini.
      final jarak =
          (NapakColors.ember.r - NapakColors.primary.r).abs() +
          (NapakColors.ember.b - NapakColors.primary.b).abs();
      expect(jarak, greaterThan(0.5));
    });

    test('kanvas malam jauh lebih gelap daripada latar utama', () {
      expect(
        NapakColors.malam.computeLuminance(),
        lessThan(NapakColors.base.computeLuminance() / 10),
      );
    });

    testWidgets('tema gelap memberi teks terang, bukan teks biru gelap', (
      tester,
    ) async {
      late TextStyle gaya;
      await tester.pumpWidget(
        MaterialApp(
          theme: NapakTheme.gelap(),
          home: Builder(
            builder: (context) {
              gaya = Theme.of(context).textTheme.bodyLarge!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Teks `textPrimary` di atas `malam` nyaris tidak terbaca — persis
      // jenis kesalahan yang lolos di layar terang pengembang.
      expect(gaya.color!.computeLuminance(), greaterThan(0.5));
    });
  });
}
