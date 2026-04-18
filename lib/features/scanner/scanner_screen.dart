import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/spacing.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'ocr_pipeline.dart';

/// Bill scanner screen.
///
/// State machine:
///   idle → shutter/pick → capturing → processing (shimmer) → done
///
/// Design:
///  • Full-screen camera preview, dark vignette, forest corner brackets
///  • Gallery icon (top-right) for picking an existing photo
///  • Torch toggle (top-left) with on/off state indicator
///  • Pulsing dot + sequenced status text + receipt skeleton during processing
///  • Source badge ("Gemini Vision" / "ML Kit") shown after result
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camera;
  _ScannerState _state = _ScannerState.idle;
  String _statusText = 'Point camera at a receipt';
  int _statusStep = 0;
  bool _torchOn = false;

  static const _processingSteps = [
    'Reading receipt…',
    'Identifying items…',
    'Almost done…',
  ];

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  final _picker = ImagePicker();

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
    if (cameras.isEmpty || !mounted) return;

    _camera = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await _camera!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Camera unavailable — use gallery ↗');
      }
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _pulseController.dispose();
    OcrPipeline.dispose();
    super.dispose();
  }

  // ── Torch toggle ──────────────────────────────────────────────────────────

  Future<void> _toggleTorch() async {
    if (_camera == null) return;
    await Haptics.lightTap();
    final next = _torchOn ? FlashMode.off : FlashMode.torch;
    await _camera!.setFlashMode(next);
    setState(() => _torchOn = !_torchOn);
  }

  // ── Camera shutter ────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_camera == null || _state != _ScannerState.idle) return;
    await Haptics.shutter();
    setState(() => _state = _ScannerState.capturing);

    try {
      final xFile = await _camera!.takePicture();
      // Turn off torch after capture so battery isn't wasted
      if (_torchOn) {
        await _camera!.setFlashMode(FlashMode.off);
        setState(() => _torchOn = false);
      }
      _startProcessing(File(xFile.path));
    } catch (e) {
      setState(() {
        _state = _ScannerState.idle;
        _statusText = "Couldn't capture. Try again.";
      });
    }
  }

  // ── Gallery pick ──────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    if (_state != _ScannerState.idle) return;
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90, // light pre-compress; OcrPipeline compresses further
    );
    if (xFile == null || !mounted) return;
    await Haptics.lightTap();
    _startProcessing(File(xFile.path));
  }

  // ── Processing ────────────────────────────────────────────────────────────

  void _startProcessing(File image) {
    setState(() {
      _state = _ScannerState.processing;
      _statusText = _processingSteps[0];
      _statusStep = 0;
    });

    // Cycle status text every 900ms during processing
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

    OcrPipeline.process(image).then((result) {
      if (!mounted) return;
      setState(() => _state = _ScannerState.done);
      // Pass both the OcrResult and the source File so ItemReviewScreen
      // can upload the receipt image after the user confirms items.
      context.go(AppRoutes.itemReview, extra: {
        'result': result,
        'imageFile': image,
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _state = _ScannerState.idle;
        _statusText = "Couldn't read receipt. Try retaking.";
      });
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────────
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

          // Dark radial vignette
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.transparent, Color(0x80000000)],
              ),
            ),
          ),

          // ── Forest corner brackets ──────────────────────────────────────
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

          // ── Top bar ────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: Spacing.xs),
                child: Row(
                  children: [
                    // Close
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    // Torch toggle with on/off indicator
                    if (_camera != null)
                      _TorchButton(
                        isOn: _torchOn,
                        onTap: _toggleTorch,
                      ),
                    const SizedBox(width: Spacing.xs),
                    // Gallery pick
                    _GalleryButton(onTap: _pickFromGallery),
                  ],
                ),
              ),
            ),
          ),

          // ── Processing overlay ──────────────────────────────────────────
          if (_state == _ScannerState.processing) ...[
            Container(color: const Color(0xCC000000)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.forest.withOpacity(_pulse.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_statusStep),
                      style: AppTextStyles.bodyMedium(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                  const ReceiptSkeleton(),
                  const SizedBox(height: Spacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.xs),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '✦ Gemini Vision · ML Kit',
                      style: AppTextStyles.caption(color: Colors.white70)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Bottom controls ─────────────────────────────────────────────
          if (_state != _ScannerState.processing)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xl),
                  child: Column(
                    children: [
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
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _state == _ScannerState.capturing
                                ? AppColors.forest
                                : Colors.white,
                            border: Border.all(
                                color: AppColors.forest, width: 3),
                          ),
                          child: _state == _ScannerState.capturing
                              ? const Center(
                                  child: SizedBox(
                                    width: 24, height: 24,
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

                      TextButton(
                        onPressed: () => context.go(AppRoutes.addExpense),
                        child: Text(
                          'Enter manually instead',
                          style: AppTextStyles.caption(color: Colors.white60),
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

// ─── State ───────────────────────────────────────────────────────────────────
enum _ScannerState { idle, capturing, processing, done }

// ─── Torch button ────────────────────────────────────────────────────────────
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.isOn, required this.onTap});
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isOn
              ? Colors.amber.withOpacity(0.3)
              : Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isOn ? Icons.flash_on : Icons.flash_off,
          color: isOn ? Colors.amber : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ─── Gallery button ──────────────────────────────────────────────────────────
class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.photo_library_outlined,
            color: Colors.white, size: 22),
      ),
    );
  }
}

// ─── Corner bracket painter ──────────────────────────────────────────────────
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

    canvas.drawLine(Offset(0, cl), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(cl, 0), paint);
    canvas.drawLine(Offset(w - cl, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cl), paint);
    canvas.drawLine(Offset(0, h - cl), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(cl, h), paint);
    canvas.drawLine(Offset(w - cl, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cl), paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
