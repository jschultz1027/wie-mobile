import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/zone_attributes.dart';
import '../services/zone_manager_service.dart';

Color _riskColorForMZone(double mZone) {
  if (mZone >= 2.2) return Colors.red;
  if (mZone >= 1.8) return Colors.orange;
  if (mZone >= 1.4) return Colors.amber;
  return AppColors.success;
}

/// Map image with existing zone polygons overlay. Optional in-place drawing mode.
/// Pinch-zoom and pan via InteractiveViewer.
class PropertyMapWithZones extends StatefulWidget {
  final String mapImageUrl;
  final List<ZoneAttributes> zones;
  final double height;
  /// When true, taps on the map add points and preview polygon is drawn.
  final bool isDrawing;
  final List<ZoneGeometryPoint> drawingPoints;
  /// Called with image coords when user taps and isDrawing is true.
  final void Function(ZoneGeometryPoint)? onTapWhenDrawing;

  const PropertyMapWithZones({
    super.key,
    required this.mapImageUrl,
    required this.zones,
    this.height = 280,
    this.isDrawing = false,
    this.drawingPoints = const [],
    this.onTapWhenDrawing,
  });

  @override
  State<PropertyMapWithZones> createState() => _PropertyMapWithZonesState();
}

class _PropertyMapWithZonesState extends State<PropertyMapWithZones> {
  final ZoneManagerService _api = ZoneManagerService();
  ui.Image? _image;
  double _imageWidth = 0;
  double _imageHeight = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(PropertyMapWithZones oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapImageUrl != widget.mapImageUrl) _loadImage();
  }

  void _onTapDown(TapDownDetails details, Size containerSize) {
    if (!widget.isDrawing || widget.onTapWhenDrawing == null ||
        _image == null || _imageWidth <= 0 || _imageHeight <= 0) return;
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
    widget.onTapWhenDrawing!(ZoneGeometryPoint(x: imageX, y: imageY));
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.grey.shade600),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700), textAlign: TextAlign.center),
              TextButton(onPressed: _loadImage, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 4.0,
          panEnabled: true,
          scaleEnabled: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final stack = Stack(
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
                    child: CustomPaint(
                      painter: _ZonesOverlayPainter(
                        zones: widget.zones,
                        imageWidth: _imageWidth,
                        imageHeight: _imageHeight,
                        containerSize: size,
                      ),
                    ),
                  ),
                  if (widget.isDrawing && widget.drawingPoints.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DrawingPreviewPainter(
                          drawingPoints: List<ZoneGeometryPoint>.from(widget.drawingPoints),
                          imageWidth: _imageWidth,
                          imageHeight: _imageHeight,
                          containerSize: size,
                        ),
                      ),
                    ),
                ],
              );
              if (widget.isDrawing) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _onTapDown(d, size),
                  child: stack,
                );
              }
              return stack;
            },
          ),
        ),
      ),
    );
  }
}

class _ZonesOverlayPainter extends CustomPainter {
  final List<ZoneAttributes> zones;
  final double imageWidth;
  final double imageHeight;
  final Size containerSize;

  _ZonesOverlayPainter({
    required this.zones,
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
    for (final zone in zones) {
      if (zone.geometry.isEmpty || zone.geometry.length < 3) continue;
      final displayPoints = zone.geometry.map(_toDisplay).toList();
      final path = Path()..addPolygon(displayPoints, true);
      final mZone = calculateMZone(zone);
      final color = _riskColorForMZone(mZone);
      final fillPaint = Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZonesOverlayPainter old) {
    return old.zones != zones ||
        old.imageWidth != imageWidth ||
        old.imageHeight != imageHeight ||
        old.containerSize != containerSize;
  }
}

class _DrawingPreviewPainter extends CustomPainter {
  final List<ZoneGeometryPoint> drawingPoints;
  final double imageWidth;
  final double imageHeight;
  final Size containerSize;

  _DrawingPreviewPainter({
    required this.drawingPoints,
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
    if (drawingPoints.isEmpty) return;
    final displayPoints = drawingPoints.map(_toDisplay).toList();
    final fillPaint = Paint()
      ..color = AppColors.blue600.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.blue600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (displayPoints.length > 1) {
      final path = Path()..addPolygon(displayPoints, true);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }
    final dotPaint = Paint()
      ..color = AppColors.blue600
      ..style = PaintingStyle.fill;
    for (final o in displayPoints) {
      canvas.drawCircle(o, 6, dotPaint);
      canvas.drawCircle(o, 6, Paint()..color = AppColors.blue600..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPreviewPainter old) {
    return old.drawingPoints != drawingPoints ||
        old.imageWidth != imageWidth ||
        old.imageHeight != imageHeight ||
        old.containerSize != containerSize;
  }
}
