import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';

class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh(this.ref) {
    // Listen to any change in authProvider
    ref.listen<bool>(authProvider, (_, __) {
      notifyListeners(); // Trigger router rebuild
    });
  }

  final Ref ref;
}
