import 'dart:ui' show ImageFilter;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/service_locator.dart';
import '../../services/camera_service.dart';

class SessionCameraPreview extends StatelessWidget {
  const SessionCameraPreview({
    super.key,
    required this.controller,
    required this.initFuture,
    required this.warmingUp,
    this.cameraScale = 1.08, // slight zoom-in to match Snapchat-style crop
  });

  final CameraController? controller;
  final Future<void>? initFuture;
  final bool warmingUp;

  /// How much to scale the camera preview inside the crop
  final double cameraScale;

  @override
  Widget build(BuildContext context) {
    if (controller == null || initFuture == null) {
      return const _WarmupView(message: 'Preparing camera…');
    }

    return FutureBuilder<void>(
      future: initFuture,
      builder: (_, snap) {
        final ready =
            snap.connectionState == ConnectionState.done && controller!.value.isInitialized;

        final showLive = ready && !warmingUp;

        final value = controller!.value;
        final previewSize = value.previewSize;

        final bool isFrontCamera =
            controller!.description.lensDirection == CameraLensDirection.front;

        // Build the raw camera preview, mirroring only if it's the front camera.
        Widget camera = CameraPreview(controller!);

        if (isFrontCamera) {
          camera = Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
            child: camera,
          );
        }

        final preview = SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final dx = details.localPosition.dx / constraints.maxWidth;
                  final dy = details.localPosition.dy / constraints.maxHeight;
                  sl<CameraService>().tapToFocus(Offset(dx, dy));
                },
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: (previewSize?.height ?? 720) * cameraScale,
                      height: (previewSize?.width ?? 1280) * cameraScale,
                      child: camera,
                    ),
                  ),
                ),
              );
            },
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview with smooth fade and blur transition
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              opacity: showLive ? 1 : 0,
              child: _BlurTransition(
                isBlurred: !showLive,
                child: preview,
              ),
            ),
            // Warmup view (underneath the camera)
            if (!showLive) const _WarmupView(message: 'Warming up camera…'),
            // Optional "camera warming up" overlay pill
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: warmingUp ? const _WarmupOverlay() : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

/// Smoothly transitions blur on/off for the camera preview.
class _BlurTransition extends StatelessWidget {
  const _BlurTransition({
    required this.isBlurred,
    required this.child,
  });

  final bool isBlurred;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 8, end: isBlurred ? 8 : 0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, sigma, child) {
        // Skip blur filter when sigma is effectively 0 for performance
        if (sigma < 0.5) return child!;
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _WarmupView extends StatefulWidget {
  const _WarmupView({this.message = 'Warming up camera…'});

  final String message;

  @override
  State<_WarmupView> createState() => _WarmupViewState();
}

class _WarmupViewState extends State<_WarmupView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
            CurvedAnimation(parent: _c, curve: Curves.easeInOut),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera_front_rounded, color: Colors.white70, size: 36),
              const SizedBox(height: 12),
              Text(
                widget.message,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarmupOverlay extends StatelessWidget {
  const _WarmupOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.black26,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Optimizing camera…',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
