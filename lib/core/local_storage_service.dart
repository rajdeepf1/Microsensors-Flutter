// lib/core/local_storage_service.dart
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _userKey = 'logged_in_user';

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.toRawJson());
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    return UserModel.fromRawJson(raw);
  }

  Future<void> removeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
