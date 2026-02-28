/// Floating debug overlay that allows switching tiers at runtime during development.
import 'package:flutter/widgets.dart';

class DebugOverlay extends StatefulWidget {
  const DebugOverlay({super.key});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  // TODO: implement tier switcher UI for debug builds

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
