import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SessionCameraPreview extends StatelessWidget {
  const SessionCameraPreview({
    super.key,
    required this.controller,
    required this.initFuture,
    required this.warmingUp,
    this.portraitAspect = 3 / 4,
  });

  final CameraController? controller;
  final Future<void>? initFuture;
  final bool warmingUp;
  final double portraitAspect;

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

        final preview = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
          child: Transform.scale(
            scale: 1.08,
            child: CameraPreview(controller!),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF2D59C), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66F2D59C),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Color(0x33F8E7C3),
                        blurRadius: 48,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: portraitAspect,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: controller!.value.previewSize?.height ?? 1280,
                          height: controller!.value.previewSize?.width ?? 720,
                          child: preview,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Optional "camera warming up" overlay even after init completes (rare but nice)
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