/// InheritedWidget that exposes the current tier and configuration down the widget tree.
import 'package:flutter/widgets.dart';

class SubscriptionGuardScope extends InheritedWidget {
  const SubscriptionGuardScope({super.key, required super.child});

  // TODO: implement scope fields and of() accessor

  @override
  bool updateShouldNotify(covariant SubscriptionGuardScope oldWidget) {
    return false; // TODO: implement change detection
  }
}
