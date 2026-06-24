import 'package:flutter/material.dart';

/// Shared navigation for returning to [HomeScreen] from the drawer or deep links.
class HomeScreenActions {
  static VoidCallback? _scrollToTop;

  static void registerScrollToTop(VoidCallback callback) {
    _scrollToTop = callback;
  }

  static void unregisterScrollToTop(VoidCallback callback) {
    if (_scrollToTop == callback) _scrollToTop = null;
  }

  /// Closes the drawer (if open), pops back to home, and scrolls to the top.
  static void goHome(BuildContext context) {
    final navigator = Navigator.of(context);
    final scaffold = Scaffold.maybeOf(context);

    if (scaffold?.isDrawerOpen == true) {
      navigator.pop(); // close drawer only
    }

    navigator.popUntil((route) => route.isFirst);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTop?.call();
    });
  }
}
