import 'package:flutter/material.dart';

/// A round, logo-only sign-in button (Google / Facebook / email / phone).
/// [tooltip] doubles as the accessibility label since there is no text.
/// [caption] is the short visible name under the circle ("Google", "Email"),
/// so nobody has to guess what a bare logo or envelope does.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.child,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
    this.caption,
  });

  final Widget child;
  final String? caption;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: scheme.surface,
          shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: isLoading ? null : onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Opacity(opacity: onPressed == null ? 0.4 : 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
    final caption = this.caption;
    if (caption == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 4),
        // The circle already announces itself; the caption is for eyes only.
        ExcludeSemantics(
          child: Text(caption, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// Google's "G" in its four brand colors, drawn as a gradient-free sweep so
/// no image asset is needed.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const SweepGradient(
        colors: [
          Color(0xFF4285F4), // blue
          Color(0xFF34A853), // green
          Color(0xFFFBBC05), // yellow
          Color(0xFFEA4335), // red
          Color(0xFF4285F4),
        ],
        stops: [0.0, 0.3, 0.5, 0.75, 1.0],
        transform: GradientRotation(-0.6),
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(
        'G',
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1, color: Colors.white),
      ),
    );
  }
}

/// Facebook's white "f" on its brand-blue disc.
class FacebookLogo extends StatelessWidget {
  const FacebookLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.bottomCenter,
      decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
      child: Text(
        'f',
        style: TextStyle(fontSize: size * 0.9, fontWeight: FontWeight.w800, height: 1.05, color: Colors.white),
      ),
    );
  }
}

/// Apple's logo glyph (Material has no Apple icon; U+F8FF renders as the
/// Apple logo on Apple platforms, where this button is the only place shown).
class AppleLogo extends StatelessWidget {
  const AppleLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      '\uF8FF',
      style: TextStyle(fontSize: size, height: 1, color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
