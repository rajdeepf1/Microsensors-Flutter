// core/local_storage_service.dart (or where you placed it)
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microsensors/models/user_model/user_model.dart'; // ensure it exports UserDataModel

class LocalStorageService {
  static const _userKey = 'logged_in_user';

  Future<void> saveUser(UserDataModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<UserDataModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserDataModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
