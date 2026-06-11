import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/zone_attributes.dart';
import '../../services/zone_manager_service.dart';

/// Draw a zone polygon on the map by tapping points. Returns geometry (x,y in image coords) on Finish.
/// See docs/ZONE_MANAGER_LOGIC_FOR_FLUTTER.md.
class DrawZoneScreen extends StatefulWidget {
  final int propertyId;
  final String mapImageUrl;

  const DrawZoneScreen({super.key, required this.propertyId, required this.mapImageUrl});

  @override
  State<DrawZoneScreen> createState() => _DrawZoneScreenState();
}

class _DrawZoneScreenState extends State<DrawZoneScreen> {
  final ZoneManagerService _api = ZoneManagerService();
  ui.Image? _image;
  double _imageWidth = 0;
  double _imageHeight = 0;
  final List<ZoneGeometryPoint> _points = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await _api.getMapImageBytes(widget.mapImageUrl);
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image = frame.image;
          _imageWidth = frame.image.width.toDouble();
          _imageHeight = frame.image.height.toDouble();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onTapDown(TapDownDetails details, Size containerSize) {
    if (_image == null || _imageWidth <= 0 || _imageHeight <= 0) return;
    // Fitted rect for BoxFit.contain (same math as _PolygonPreviewPainter)
    final scaleW = containerSize.width / _imageWidth;
    final scaleH = containerSize.height / _imageHeight;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    final displayW = _imageWidth * scale;
    final displayH = _imageHeight * scale;
    final left = (containerSize.width - displayW) / 2;
    final top = (containerSize.height - displayH) / 2;
    final dx = details.localPosition.dx;
    final dy = details.localPosition.dy;
    if (dx < left || dx > left + displayW || dy < top || dy > top + displayH) return;
    final imageX = (dx - left) / scale;
    final imageY = (dy - top) / scale;
    setState(() {
      _points.add(ZoneGeometryPoint(x: imageX, y: imageY));
    });
  }

  void _finish() {
    if (_points.length < 3) return;
    Navigator.of(context).pop(_points);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _cancel,
        ),
        title: const Text(
          'Draw Zone',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _points.length >= 3 ? _finish : null,
            child: Text(
              'Finish (${_points.length} pts)',
              style: TextStyle(
                color: _points.length >= 3 ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadImage,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_image != null)
                          Positioned.fill(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: _imageWidth,
                                height: _imageHeight,
                                child: RawImage(
                                  image: _image!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _onTapDown(d, size),
                            child: CustomPaint(
                              painter: _PolygonPreviewPainter(
                                points: List<ZoneGeometryPoint>.from(_points),
                                imageWidth: _imageWidth,
                                imageHeight: _imageHeight,
                                containerSize: size,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Tap on the map to add points. Need at least 3 points, then tap Finish.',
                              style: TextStyle(color: Colors.grey.shade200, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

/// Paints polygon and point markers in image coordinate space, scaled to container.
class _PolygonPreviewPainter extends CustomPainter {
  final List<ZoneGeometryPoint> points;
  final double imageWidth;
  final double imageHeight;
  final Size containerSize;

  _PolygonPreviewPainter({
    required this.points,
    required this.imageWidth,
    required this.imageHeight,
    required this.containerSize,
  });

  Offset _toDisplay(ZoneGeometryPoint p) {
    if (imageWidth <= 0 || imageHeight <= 0) return Offset.zero;
    final scaleW = containerSize.width / imageWidth;
    final scaleH = containerSize.height / imageHeight;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    final displayW = imageWidth * scale;
    final displayH = imageHeight * scale;
    final left = (containerSize.width - displayW) / 2;
    final top = (containerSize.height - displayH) / 2;
    final x = (p.x ?? 0) * scale + left;
    final y = (p.y ?? 0) * scale + top;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final displayPoints = points.map(_toDisplay).toList();
    // Fill
    final fillPaint = Paint()
      ..color = AppColors.blue600.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final path = Path()..addPolygon(displayPoints, true);
    canvas.drawPath(path, fillPaint);
    // Stroke
    final strokePaint = Paint()
      ..color = AppColors.blue600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, strokePaint);
    // Point markers
    final dotPaint = Paint()
      ..color = AppColors.blue600
      ..style = PaintingStyle.fill;
    for (final o in displayPoints) {
      canvas.drawCircle(o, 6, dotPaint);
      canvas.drawCircle(o, 6, strokePaint..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonPreviewPainter old) {
    return old.points != points ||
        old.imageWidth != imageWidth ||
        old.imageHeight != imageHeight ||
        old.containerSize != containerSize;
  }
}
