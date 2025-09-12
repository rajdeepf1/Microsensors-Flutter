import 'package:flutter/foundation.dart';
import '../models/user_model/user_model.dart';

/// Simple global app state holder for small, app-wide values.
/// Use AppState.instance.currentUser to listen/emit user updates.
class AppState {
  AppState._();

  static final AppState instance = AppState._();

  /// Holds latest logged-in user (or null).
  final ValueNotifier<UserDataModel?> currentUser = ValueNotifier<UserDataModel?>(null);

  /// Convenience helper to update user and broadcast to listeners.
  void updateUser(UserDataModel? user) => currentUser.value = user;
}
