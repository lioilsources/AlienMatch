import 'package:flutter/widgets.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import 'telemetry_dictionary.dart';

/// Screens for `ol1n_telemetry`. Pushed routes are reported by their name
/// ([kScreenRoutes]); the root route (`MaterialApp.home`, named `/`) shows
/// whatever stage or home tab is current, which the widgets report through
/// [AppScreens.root]. A root screen is only reported while nothing is pushed
/// on top of it, and comes back when the pushed route is popped.
///
/// Measuring never steers the app: nothing reads from this class.
class AppScreens extends TelemetryNavigatorObserver {
  AppScreens() : super(kScreenRoutes) {
    _current = this;
  }

  static AppScreens? _current;

  /// The stage or tab now on the root route (one of [kRootScreens]).
  static void root(String screen) => _current?._setRoot(screen);

  String _root = 'loading';
  Route<dynamic>? _top;

  bool get _onRoot => _top == null || _top!.isFirst;

  void _setRoot(String screen) {
    _root = screen;
    if (_onRoot) Telemetry.screen(screen);
  }

  @override
  String screenOf(Route<dynamic> route) =>
      route.isFirst || route.settings.name == '/'
      ? _root
      : super.screenOf(route);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _top = route;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute is PageRoute) _top = previousRoute;
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRoute && newRoute.isCurrent) _top = newRoute;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute &&
        previousRoute is PageRoute &&
        previousRoute.isCurrent) {
      _top = previousRoute;
    }
    super.didRemove(route, previousRoute);
  }
}
