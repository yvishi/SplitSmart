import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'ocr_pipeline.dart';

/// The scanner brand moment — 3–4 seconds users spend watching SplitSmart work.
///
/// State machine:
///   idle → shutter (haptic) → capturing → processing (shimmer) → done
///
/// Key design details:
///  • Full-screen camera preview, no other chrome
///  • Forest green corner brackets (custom painter)
///  • Pulsing green dot during processing
///  • Sequenced status text: "Reading receipt…" → "Identifying items…" → "Almost done…"
///  • ML Kit badge bottom-left, shimmer receipt skeleton bottom-center
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  _ScannerState _state = _ScannerState.idle;
  String _statusText = 'Point at a receipt';
  int _statusStep = 0;

  // Processing status messages — sequenced every 900ms
  static const _processingSteps = [
    'Reading receipt…',
    'Identifying items…',
    'Almost done…',
  ];

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _camera = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _camera!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _camera?.dispose();
    _pulseController.dispose();
    OcrPipeline.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_camera == null || _state != _ScannerState.idle) return;

    // Shutter haptic — the tactile confirmation
    await Haptics.shutter();
    setState(() => _state = _ScannerState.capturing);

    try {
      final file = await _camera!.takePicture();
      _startProcessing(File(file.path));
    } catch (e) {
      setState(() {
        _state = _ScannerState.idle;
        _statusText = 'Couldn\'t capture. Try again.';
      });
    }
  }

  void _startProcessing(File image) {
    setState(() {
      _state = _ScannerState.processing;
      _statusText = _processingSteps[0];
      _statusStep = 0;
    });

    // Sequence status text every 900ms
    for (int i = 1; i < _processingSteps.length; i++) {
      Future.delayed(Duration(milliseconds: 900 * i), () {
        if (mounted && _state == _ScannerState.processing) {
          setState(() {
            _statusStep = i;
            _statusText = _processingSteps[i];
          });
        }
      });
    }

    // Run OCR pipeline
    OcrPipeline.process(image).then((result) {
      if (!mounted) return;
      setState(() => _state = _ScannerState.done);
      context.go(AppRoutes.itemReview, extra: result);
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _state = _ScannerState.idle;
        _statusText = 'Couldn\'t read receipt. Try again.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ───────────────────────────────────────────────
          if (_camera != null && _camera!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _camera!.value.previewSize!.height,
                  height: _camera!.value.previewSize!.width,
                  child: CameraPreview(_camera!),
                ),
              ),
            )
          else
            const ColoredBox(color: Colors.black),

          // Dark vignette overlay
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.transparent, Color(0x80000000)],
              ),
            ),
          ),

          // ── Forest corner brackets ───────────────────────────────────────
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 56, vertical: 180),
              child: CustomPaint(
                painter: _BracketPainter(
                  color: AppColors.forest,
                  strokeWidth: 3,
                  cornerLength: 24,
                ),
              ),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.base, vertical: Spacing.sm),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    // Torch toggle
                    if (_camera != null)
                      IconButton(
                        icon: const Icon(
                            Icons.flash_auto_outlined,
                            color: Colors.white),
                        onPressed: () =>
                            _camera!.setFlashMode(FlashMode.torch),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Processing overlay ───────────────────────────────────────────
          if (_state == _ScannerState.processing) ...[
            // Blurred black overlay
            Container(color: const Color(0xCC000000)),

            // Shimmer skeleton receipt
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing green dot
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.forest
                            .withOpacity(_pulse.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),

                  // Status text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_statusStep),
                      style: AppTextStyles.bodyMedium(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),

                  // Shimmer receipt skeleton
                  const ReceiptSkeleton(),
                  const SizedBox(height: Spacing.lg),

                  // ML Kit + Gemini AI badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.xs),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius:
                          BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '✦ ML Kit · Gemini AI',
                      style: AppTextStyles.caption(
                              color: Colors.white70)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Bottom controls ──────────────────────────────────────────────
          if (_state != _ScannerState.processing)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xl),
                  child: Column(
                    children: [
                      // Status hint
                      Text(
                        _state == _ScannerState.idle
                            ? _statusText
                            : 'Processing…',
                        style: AppTextStyles.body(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.xl),

                      // Shutter button
                      GestureDetector(
                        onTap: _capture,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _state == _ScannerState.capturing
                                ? AppColors.forest
                                : Colors.white,
                            border: Border.all(
                              color: AppColors.forest,
                              width: 3,
                            ),
                          ),
                          child: _state == _ScannerState.capturing
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: Spacing.base),

                      // Manual entry fallback
                      TextButton(
                        onPressed: () =>
                            context.go(AppRoutes.addExpense),
                        child: Text(
                          'Enter manually instead',
                          style: AppTextStyles.caption(
                              color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Scanner state ────────────────────────────────────────────────────────────
enum _ScannerState { idle, capturing, processing, done }

// ─── Forest corner brackets painter ──────────────────────────────────────────
class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
  });

  final Color color;
  final double strokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cl = cornerLength;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset(0, cl), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(cl, 0), paint);

    // Top-right
    canvas.drawLine(Offset(w - cl, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cl), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, h - cl), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(cl, h), paint);

    // Bottom-right
    canvas.drawLine(Offset(w - cl, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cl), paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
