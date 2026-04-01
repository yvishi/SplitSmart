import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// The 8 deterministic background colors for avatars.
/// Assigned by name hash — never random per render.
const _avatarColors = [
  Color(0xFF1A6B4A), // Forest
  Color(0xFF6B4A1A), // Warm brown
  Color(0xFF4A1A6B), // Purple
  Color(0xFF1A4A6B), // Slate blue
  Color(0xFF6B1A4A), // Berry
  Color(0xFF4A6B1A), // Olive
  Color(0xFF6B4A4A), // Mauve
  Color(0xFF1A6B6B), // Teal
];

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.border,
    this.colorIndex,
  });

  final String name;
  final double size;

  /// Optional explicit border. Use for stacked avatars.
  final BorderSide? border;

  /// Override color index. If null, derived from name hash.
  final int? colorIndex;

  @override
  Widget build(BuildContext context) {
    final index = colorIndex ?? name.hashCode.abs() % 8;
    final bg = _avatarColors[index];
    final initials = _initials(name);
    final fontSize = size * 0.36;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: border != null
            ? Border.fromBorderSide(border!)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.caption(color: Colors.white).copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Stacked avatar cluster — shows up to [maxVisible] avatars with overlap.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    this.size = 20,
    this.maxVisible = 4,
  });

  final List<String> names;
  final double size;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = names.take(maxVisible).toList();
    final overflow = names.length - visible.length;

    return SizedBox(
      height: size,
      width: size + (visible.length - 1) * (size * 0.6),
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * (size * 0.6),
              child: AppAvatar(
                name: visible[i],
                size: size,
                border: BorderSide(
                  color: AppColors.white,
                  width: 1.5,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (size * 0.6),
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: AppColors.subtle,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: AppTextStyles.caption(color: AppColors.stone).copyWith(
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
