import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tourvella_motion.dart';

/// Pembungkus yang membuat apa pun terasa bisa ditekan.
///
/// Inilah bagian terbesar dari rasa "enak dipakai" yang orang kira datang dari
/// tata letak. Saat sebuah kartu menyusut sedikit di bawah jari lalu kembali
/// saat dilepas, otak membacanya sebagai benda, bukan gambar. Tanpa itu,
/// aplikasi sebagus apa pun terasa seperti brosur yang bisa diklik.
///
/// Gerak turunnya lebih cepat daripada naiknya — benda nyata memang begitu:
/// ditekan langsung ambles, dilepas mengendap perlahan.
class TourvellaPressable extends StatefulWidget {
  const TourvellaPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.skala = 0.97,
    this.getar = true,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Seberapa menyusut saat ditekan. Kartu besar butuh lebih sedikit
  /// daripada tombol kecil — gerak yang sama terasa berlebihan pada
  /// permukaan yang lebar.
  final double skala;

  /// Getaran halus saat disentuh. Dimatikan untuk elemen yang bisa ditekan
  /// berkali-kali cepat, supaya tidak jadi ribut.
  final bool getar;

  final BorderRadius? borderRadius;

  @override
  State<TourvellaPressable> createState() => _TourvellaPressableState();
}

class _TourvellaPressableState extends State<TourvellaPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kendali = AnimationController(
    vsync: this,
    duration: TourvellaMotion.kilat,
    reverseDuration: TourvellaMotion.cepat,
  );

  late final Animation<double> _skala = Tween(
    begin: 1.0,
    end: widget.skala,
  ).animate(CurvedAnimation(parent: _kendali, curve: TourvellaMotion.mengalir));

  @override
  void dispose() {
    _kendali.dispose();
    super.dispose();
  }

  bool get _aktif => widget.onTap != null || widget.onLongPress != null;

  void _turun(_) {
    if (!_aktif) return;
    _kendali.forward();
    if (widget.getar) HapticFeedback.selectionClick();
  }

  void _naik([_]) {
    if (!_aktif) return;
    _kendali.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _turun,
      onTapUp: _naik,
      onTapCancel: _naik,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(scale: _skala, child: widget.child),
    );
  }
}
