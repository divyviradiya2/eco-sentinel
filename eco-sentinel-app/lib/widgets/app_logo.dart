import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/logo.png',
      width: size,
      height: size,
      fit:
          ConstrainedBox(
                constraints: BoxConstraints(maxWidth: size, maxHeight: size),
              ).constraints.maxWidth >
              0
          ? BoxFit.contain
          : null,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.eco, size: size, color: Colors.green);
      },
    );
  }
}
