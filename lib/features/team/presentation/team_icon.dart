import 'package:flutter/material.dart';

/// A generic football-club-style crest showing the team's initials,
/// used as a placeholder until real team badges are available.
class TeamIcon extends StatelessWidget {
  const TeamIcon({super.key, required this.teamName, this.size = 40.0});

  final String teamName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _ShieldPainter(color: _colorForTeam(teamName)),
        child: Padding(
          padding: EdgeInsets.only(bottom: size * 0.12),
          child: Center(
            child: Text(
              _initialsFor(teamName),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.34,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return "?";
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length > 1 ? 2 : 1)
          .toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Deterministic colour per team name, so the same team always gets the
  /// same crest colour without needing a real badge asset.
  static Color _colorForTeam(String name) {
    final hash = name.codeUnits.fold<int>(0, (sum, c) => sum + c);
    final hue = (hash * 37) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.45, 0.38).toColor();
  }
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shieldPath(size);

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.05,
    );
  }

  Path _shieldPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, h * 0.10)
      ..quadraticBezierTo(0, 0, w * 0.10, 0)
      ..lineTo(w * 0.90, 0)
      ..quadraticBezierTo(w, 0, w, h * 0.10)
      ..lineTo(w, h * 0.48)
      ..quadraticBezierTo(w, h * 0.78, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.78, 0, h * 0.48)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) =>
      oldDelegate.color != color;
}
