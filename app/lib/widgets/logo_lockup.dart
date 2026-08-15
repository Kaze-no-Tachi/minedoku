import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'mine_icon.dart';

/// The game's name, set beside its mark.
///
/// The mark is the same painted glyph the board uses, so the logo, the app icon
/// and a placed mine are one shape rather than three that drift apart.
class LogoLockup extends StatelessWidget {
  const LogoLockup({
    super.key,
    required this.theme,
    this.scale = 1,
    this.showTagline = true,
  });

  final GameTheme theme;
  final double scale;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(9 * scale),
              decoration: BoxDecoration(
                color: theme.regionColor(0),
                borderRadius: BorderRadius.circular(12 * scale),
                border: Border.all(color: theme.boardOutline, width: 2.5),
              ),
              child: MineIcon(
                size: 30 * scale,
                color: theme.glyphColor,
                glyph: theme.mineGlyph,
              ),
            ),
            SizedBox(width: 12 * scale),
            Text(
              'MINEDOKU',
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 2 * scale,
                fontSize: (text.headlineMedium?.fontSize ?? 28) * scale,
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          SizedBox(height: 8 * scale),
          Text(
            'One mine per row, column and colour. '
            'None of them may touch.',
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
