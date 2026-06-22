import 'package:flutter/material.dart';
import 'help_overlay.dart';

/// Wraps a widget so tapping (or long-pressing) shows detailed help text.
///
/// On mobile there is no hover — tap or long-press triggers the help sheet.
/// Use [triggerOnLongPressOnly] when the child has its own tap handler (buttons, links).
class TapTooltip extends StatelessWidget {
  const TapTooltip({
    super.key,
    required this.message,
    required this.child,
    this.title,
    this.triggerOnLongPressOnly = false,
    this.enabled = true,
  });

  final String message;
  final String? title;
  final Widget child;
  final bool triggerOnLongPressOnly;
  final bool enabled;

  void _showHelp(BuildContext context) {
    if (!enabled) return;
    showHelpSheet(context, title: title, message: message);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: triggerOnLongPressOnly ? null : () => _showHelp(context),
      onLongPress: triggerOnLongPressOnly ? () => _showHelp(context) : null,
      child: child,
    );
  }
}

/// Small ℹ button — tap to show help without blocking parent gestures.
class HelpIcon extends StatelessWidget {
  const HelpIcon({
    super.key,
    required this.message,
    this.title,
    this.color,
    this.size = 18,
  });

  final String message;
  final String? title;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showHelpSheet(context, title: title ?? 'Help', message: message),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.info_outline,
            size: size,
            color: color ?? Colors.blue.shade400,
          ),
        ),
      ),
    );
  }
}

/// Form label with an adjacent help icon (tap icon for details).
class HelpLabel extends StatelessWidget {
  const HelpLabel({
    super.key,
    required this.label,
    required this.help,
    this.style,
    this.iconColor,
  });

  final String label;
  final String help;
  final TextStyle? style;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TapTooltip(
            title: label,
            message: help,
            child: Text(label, style: style),
          ),
        ),
        HelpIcon(message: help, title: label, color: iconColor),
      ],
    );
  }
}

/// AppBar action — overview help for the current screen.
class ScreenHelpAction extends StatelessWidget {
  const ScreenHelpAction({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, color: Colors.white),
      tooltip: 'Screen help',
      onPressed: () => showHelpSheet(context, title: title, message: message),
    );
  }
}
