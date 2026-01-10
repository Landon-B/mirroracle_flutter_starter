import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SessionCameraPreview extends StatelessWidget {
  const SessionCameraPreview({
    super.key,
    required this.controller,
    required this.initFuture,
    required this.warmingUp,
    this.cameraScale = 1.08,     // slight zoom-in to match Snapchat-style crop
  });

  final CameraController? controller;
  final Future<void>? initFuture;
  final bool warmingUp;

  /// How much to scale the camera preview inside the crop
  final double cameraScale;

  @override
  Widget build(BuildContext context) {
    if (controller == null || initFuture == null) {
      return Container(color: Colors.black);
    }

    return FutureBuilder<void>(
      future: initFuture,
      builder: (_, snap) {
        final ready =
            snap.connectionState == ConnectionState.done && controller!.value.isInitialized;

        if (!ready) {
          return const _WarmupView();
        }

        final value = controller!.value;
        final previewSize = value.previewSize;

        // Camera plugin reports size in *landscape* (width > height)
        // We want a portrait aspect ratio for the sensor itself.
        final double sensorAspectPortrait = (previewSize != null && previewSize.width > 0)
            ? previewSize.height / previewSize.width
            : 4 / 3; // sane default

        final bool isFrontCamera =
            controller!.description.lensDirection == CameraLensDirection.front;

        // Build the raw camera preview, mirroring only if it's the front camera.
        Widget camera = CameraPreview(controller!);

        if (isFrontCamera) {
          camera = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: camera,
          );
        }

        final preview = SizedBox.expand(
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

        return Stack(
          fit: StackFit.expand,
          children: [
            preview,

            // Optional "camera warming up" overlay even after init completes
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: warmingUp ? const _WarmupOverlay() : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _WarmupView extends StatefulWidget {
  const _WarmupView();

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
          opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_c),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera_front_rounded, color: Colors.white70, size: 36),
              SizedBox(height: 12),
              Text(
                'Warming up camera…',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
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
          child: const Text(
            'Optimizing camera…',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
