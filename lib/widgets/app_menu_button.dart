import 'package:flutter/material.dart';
import '../config/help_content.dart';
import 'help_overlay.dart';

/// Hamburger button that opens [Scaffold.drawer]. Use with [AppDrawer] on the same scaffold.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.menu, color: color),
      tooltip: 'Menu',
      onPressed: () {
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      onLongPress: () => showHelpSheet(
        context,
        title: 'Navigation menu',
        message: HelpContent.menuButton,
      ),
    );
  }
}
