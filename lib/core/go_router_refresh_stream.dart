import 'dart:async';
import 'package:flutter/foundation.dart';

/// A Listenable for GoRouter that listens to a Stream
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyOnChange(stream);
  }

  void notifyOnChange(Stream<dynamic> stream) {
    stream.listen((_) {
      notifyListeners(); // rebuild GoRouter when stream emits
    });
  }
}
