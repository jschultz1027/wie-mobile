import 'package:flutter/material.dart';
import '../config/help_content.dart';
import 'help_overlay.dart';

/// Refresh icon that rotates continuously while [spinning] is true.
class SpinningRefreshIcon extends StatefulWidget {
  const SpinningRefreshIcon({
    super.key,
    required this.spinning,
    this.color = Colors.white,
    this.size = 24,
  });

  final bool spinning;
  final Color color;
  final double size;

  @override
  State<SpinningRefreshIcon> createState() => _SpinningRefreshIconState();
}

class _SpinningRefreshIconState extends State<SpinningRefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.spinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SpinningRefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !oldWidget.spinning) {
      _controller.repeat();
    } else if (!widget.spinning && oldWidget.spinning) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh, color: widget.color, size: widget.size),
    );
  }
}

/// AppBar refresh button with a spinning icon while [loading].
class RefreshIconButton extends StatelessWidget {
  const RefreshIconButton({
    super.key,
    required this.loading,
    required this.onPressed,
    this.color = Colors.white,
    this.tooltip = 'Refresh',
    this.helpMessage = HelpContent.refreshButton,
  });

  final bool loading;
  final VoidCallback onPressed;
  final Color color;
  final String tooltip;
  final String helpMessage;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SpinningRefreshIcon(spinning: loading, color: color),
      tooltip: tooltip,
      onPressed: loading ? null : onPressed,
      onLongPress: () => showHelpSheet(
        context,
        title: 'Refresh',
        message: helpMessage,
      ),
    );
  }
}
