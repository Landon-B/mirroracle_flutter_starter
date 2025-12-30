import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SessionCameraPreview extends StatelessWidget {
  const SessionCameraPreview({
    super.key,
    required this.controller,
    required this.initFuture,
    this.portraitAspect = 3 / 4,
  });

  final CameraController? controller;
  final Future<void>? initFuture;
  final double portraitAspect;

  @override
  Widget build(BuildContext context) {
    if (controller == null || initFuture == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          'No camera available (simulator)',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return FutureBuilder(
      future: initFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done ||
            !controller!.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final preview = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
          child: Transform.scale(
            scale: 1.08,
            child: CameraPreview(controller!),
          ),
        );

        return Center(
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
        );
      },
    );
  }
}
