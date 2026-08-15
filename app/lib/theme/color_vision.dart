import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The three common forms of inherited colour blindness.
enum ColorVision {
  /// Ordinary trichromatic vision.
  typical('Typical'),

  /// Red-blind. Roughly 1% of men.
  protanopia('Protanopia'),

  /// Green-blind. Roughly 1% of men, and the most common dichromacy.
  deuteranopia('Deuteranopia'),

  /// Blue-blind. Rare, and affects all genders about equally.
  tritanopia('Tritanopia');

  const ColorVision(this.label);

  final String label;
}

/// Simulates colour blindness and measures how far apart two colours look.
///
/// This exists so the theme catalogue can be *tested* rather than assumed
/// safe. A game whose central rule is "one mine per colour" cannot ship a
/// palette that collapses into three colours for one player in twelve, and the
/// only way to know is to measure it.
///
/// Simulation uses the Machado, Oliveira and Fernandes (2009) matrices at full
/// severity, applied in linear RGB. Separation is CIE76: Euclidean distance in
/// CIELAB. CIEDE2000 is more accurate for near-identical colours, but CIE76 is
/// transparent and more than adequate for "can these two fills be told apart
/// across a board".
abstract final class ColorVisionCheck {
  /// Below this, two regions read as the same colour at a glance.
  ///
  /// Chosen from measurement rather than theory: the shipped palettes sit
  /// comfortably above it, and pairs that fall under it are visibly muddled
  /// when rendered side by side.
  static const double minimumSeparation = 18.0;

  static const Map<ColorVision, List<double>> _matrices = {
    ColorVision.typical: [1, 0, 0, 0, 1, 0, 0, 0, 1],
    ColorVision.protanopia: [
      0.152286, 1.052583, -0.204868, //
      0.114503, 0.786281, 0.099216, //
      -0.003882, -0.048116, 1.051998,
    ],
    ColorVision.deuteranopia: [
      0.367322, 0.860646, -0.227968, //
      0.280085, 0.672501, 0.047413, //
      -0.011820, 0.042940, 0.968881,
    ],
    ColorVision.tritanopia: [
      1.255528, -0.076749, -0.178779, //
      -0.078411, 0.930809, 0.147602, //
      0.004733, 0.691367, 0.303900,
    ],
  };

  /// [color] as someone with [vision] would see it.
  static Color simulate(Color color, ColorVision vision) {
    final m = _matrices[vision]!;
    final r = _toLinear(color.r);
    final g = _toLinear(color.g);
    final b = _toLinear(color.b);

    return Color.from(
      alpha: color.a,
      red: _fromLinear(m[0] * r + m[1] * g + m[2] * b),
      green: _fromLinear(m[3] * r + m[4] * g + m[5] * b),
      blue: _fromLinear(m[6] * r + m[7] * g + m[8] * b),
    );
  }

  /// Perceptual distance between two colours, as seen with [vision].
  static double separation(Color a, Color b, ColorVision vision) {
    final labA = _toLab(simulate(a, vision));
    final labB = _toLab(simulate(b, vision));
    final dl = labA[0] - labB[0];
    final da = labA[1] - labB[1];
    final db = labA[2] - labB[2];
    return math.sqrt(dl * dl + da * da + db * db);
  }

  /// The closest pair in [colors] across every form of vision.
  ///
  /// This is the number that decides whether a palette stands on its own.
  static PaletteAudit audit(List<Color> colors) {
    var worst = double.infinity;
    var worstPair = (0, 0);
    var worstVision = ColorVision.typical;

    for (final vision in ColorVision.values) {
      for (var i = 0; i < colors.length; i++) {
        for (var j = i + 1; j < colors.length; j++) {
          final distance = separation(colors[i], colors[j], vision);
          if (distance < worst) {
            worst = distance;
            worstPair = (i, j);
            worstVision = vision;
          }
        }
      }
    }
    return PaletteAudit(
      closestPair: worstPair,
      separation: worst,
      vision: worstVision,
    );
  }

  /// Relative luminance, for deciding whether dark or light glyphs sit better
  /// on a fill.
  static double luminance(Color color) =>
      0.2126 * _toLinear(color.r) +
      0.7152 * _toLinear(color.g) +
      0.0722 * _toLinear(color.b);

  // ------------------------------------------------------------- conversions

  static double _toLinear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  static double _fromLinear(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return clamped <= 0.0031308
        ? clamped * 12.92
        : 1.055 * math.pow(clamped, 1 / 2.4).toDouble() - 0.055;
  }

  /// CIELAB under a D65 white point.
  static List<double> _toLab(Color color) {
    final r = _toLinear(color.r);
    final g = _toLinear(color.g);
    final b = _toLinear(color.b);

    final x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
    final y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b) / 1.00000;
    final z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;

    double f(double t) => t > 0.008856
        ? math.pow(t, 1 / 3).toDouble()
        : (7.787 * t) + (16 / 116);

    return [
      116 * f(y) - 16,
      500 * (f(x) - f(y)),
      200 * (f(y) - f(z)),
    ];
  }
}

/// The weakest link in a palette.
class PaletteAudit {
  const PaletteAudit({
    required this.closestPair,
    required this.separation,
    required this.vision,
  });

  /// Indices of the two colours that are hardest to tell apart.
  final (int, int) closestPair;

  /// How far apart they are, in CIELAB units.
  final double separation;

  /// The form of vision under which they are closest.
  final ColorVision vision;

  /// Whether the palette carries itself without patterns.
  bool get isSafe => separation >= ColorVisionCheck.minimumSeparation;

  @override
  String toString() => 'closest pair ${closestPair.$1}/${closestPair.$2} at '
      '${separation.toStringAsFixed(1)} under ${vision.label}';
}
