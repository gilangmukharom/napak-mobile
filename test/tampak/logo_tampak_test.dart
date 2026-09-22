import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourvella/core/theme/tourvella_colors.dart';
import 'package:tourvella/core/widgets/tourvella_logo.dart';

/// Tampak `LogoTourvella`: gelap, terang, dan dua tahap animasinya.
///
/// Dipakai untuk memastikan geometri painter Flutter sama dengan ikon SVG di
/// `branding/` — bandingkan `logo.png` dengan `branding/hasil/ikon-1024.png`.
///
/// ```
/// TOURVELLA_TAMPAK=1 flutter test --update-goldens test/tampak
/// ```
void main() {
  testWidgets(
    'tampak logo Tourvella',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 340);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Widget kotak(Color latar, Widget anak) => Container(
        width: 260,
        height: 260,
        color: latar,
        alignment: Alignment.center,
        child: anak,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: TourvellaColors.base,
            body: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  kotak(
                    TourvellaColors.malam,
                    const LogoTourvella(ukuran: 220, bukit: true),
                  ),
                  kotak(
                    TourvellaColors.base,
                    const LogoTourvella(ukuran: 220, gelap: false),
                  ),
                  kotak(
                    TourvellaColors.malam,
                    const LogoTourvella(ukuran: 220, progres: 0.35),
                  ),
                  kotak(
                    TourvellaColors.malam,
                    const LogoTourvella(ukuran: 220, progres: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('logo.png'),
      );
    },
    skip: !Platform.environment.containsKey('TOURVELLA_TAMPAK'),
  );
}
