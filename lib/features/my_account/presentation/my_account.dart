import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';

import '../../../core/api_state.dart';
import '../../../core/app_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/user_model/user_model.dart';
import '../../../models/user_model/user_request_model.dart';
import '../../components/main_layout/main_layout.dart';
import '../../components/user/profile_pic.dart';
import '../../components/user/user_info_edit_field.dart';
import '../../profile/repository/user_repository.dart';

class MyAccount extends HookWidget {
  const MyAccount({super.key});

  bool _isValidEmail(String s) {
    final re = RegExp(r"^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$");
    return re.hasMatch(s);
  }

  @override
  Widget build(BuildContext context) {

    final currentUser = useValueListenable(AppState.instance.currentUser);

    final formKey = useMemoized(() => GlobalKey<FormState>());


    final repo = useMemoized(() => UserRepository());
    final picked = useState<File?>(null);
    final loading = useState(false);
    final message = useState<String?>(null);

    final showOldPassword = useState(false);
    final showNewPassword = useState(false);

    final user = currentUser;
    final username = user?.username ?? "";
    final useremail = user?.email ?? "";
    final userphone = user?.mobileNumber ?? "";
    final userrole = user?.roleName ?? "";
    final imageUrl = user?.userImage;

    // controllers pre-filled with current user
    final nameCtrl = useTextEditingController(text: username);
    final emailCtrl = useTextEditingController(text: useremail);
    final phoneCtrl = useTextEditingController(text: userphone);
    final oldPassCtrl = useTextEditingController();
    final newPassCtrl = useTextEditingController();

    Future<void> pickAndUpload() async {
      try {
        final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
        if (res == null || res.files.isEmpty) return;
        final path = res.files.first.path;
        if (path == null) return;

        final file = File(path);
        picked.value = file;

        loading.value = true;
        final apiRes = await repo.uploadProfileImage(user!.userId, file);

        if (apiRes is ApiData<UserResponseModel>) {
          message.value = 'Uploaded';
          // Save updated user to SharedPreferences
          final updatedUser = apiRes.data.data; // UserDataModel inside UserResponseModel
          if (updatedUser != null) {
            await LocalStorageService().saveUser(updatedUser);
            // Broadcast to app listeners
            AppState.instance.updateUser(updatedUser);
          }
        } else if (apiRes is ApiError<UserResponseModel>) {
          message.value = apiRes.message ?? apiRes.error?.toString() ?? 'Upload failed';
        } else {
          message.value = 'Unexpected response';
        }
      } on PlatformException catch (e) {
        message.value = 'Platform error: ${e.message}';
      } on MissingPluginException {
        message.value = 'Plugin not available (restart app)';
      } finally {
        loading.value = false;
      }
    }

// submit update (validates, builds UpdateUserRequest, calls repo, updates local storage & AppState)
    Future<void> submitUpdate() async {
      // quick guard
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not loaded')));
        return;
      }

      // form-level validation
      final name = nameCtrl.text.trim();
      final email = emailCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      final oldPass = oldPassCtrl.text;
      final newPass = newPassCtrl.text;

      if (email.isNotEmpty && !_isValidEmail(email)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email')));
        return;
      }

      if (newPass.isNotEmpty && newPass.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must have at least 6 characters')));
        return;
      }

      if (newPass.isNotEmpty && oldPass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your old password to change password')));
        return;
      }

      // Build request with only changed fields
      final req = UpdateUserRequest(
        userId: user.userId,
        userName: (name.isNotEmpty && name != user.username) ? name : username,
        email: (email.isNotEmpty && email != user.email) ? email : useremail,
        phoneNumber: (phone.isNotEmpty && phone != user.mobileNumber) ? phone : userphone,
        oldPassword: oldPass.isNotEmpty ? oldPass : null,
        newPassword: newPass.isNotEmpty ? newPass : null,
      );

      final isEmpty = req.userName == null &&
          req.email == null &&
          req.phoneNumber == null &&
          req.newPassword == null;
      if (isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No changes detected')));
        return;
      }

      loading.value = true;
      try {
        final res = await repo.updateUser(req);
        if (res is ApiData<UserResponseModel>) {
          final wrapper = res.data;
          final updatedUser = wrapper.data;
          if (updatedUser != null) {
            // persist locally and broadcast
            await LocalStorageService().saveUser(updatedUser);
            AppState.instance.updateUser(updatedUser);

            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully (no user returned)')));
          }
        } else if (res is ApiError<UserResponseModel>) {
          final msg = res.message ?? res.error?.toString() ?? 'Update failed';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unexpected server response')));
        }
      } finally {
        loading.value = false;
      }
    }
    
    return MainLayout(title: "My Account", child:
    SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          ProfilePic(
            image: imageUrl!,
            userName: username,
            imageUploadBtnPress: pickAndUpload,
          ),
          const Divider(),
          Form(
            key: formKey,
            child: Column(
              children: [
                UserInfoEditField(
                  text: "Name",
                  child: TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0 * 1.5, vertical: 16.0),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                UserInfoEditField(
                  text: "Email",
                  child: TextFormField(
                    controller: emailCtrl,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0 * 1.5, vertical: 16.0),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                UserInfoEditField(
                  text: "Phone",
                  child: TextFormField(
                    controller: phoneCtrl,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor:  AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0 * 1.5, vertical: 16.0),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                UserInfoEditField(
                  text: "Role",
                  child: TextFormField(
                    initialValue: userrole,
                    enabled: false,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0 * 1.5, vertical: 16.0),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                UserInfoEditField(
                  text: "Old Password",
                  child: TextFormField(
                    controller: oldPassCtrl,
                    obscureText: !showOldPassword.value, // toggle visibility
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          showOldPassword.value ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          showOldPassword.value = !showOldPassword.value;
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0 * 1.5, vertical: 16.0,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                UserInfoEditField(
                  text: "New Password",
                  child: TextFormField(
                    controller: newPassCtrl,
                    obscureText: !showNewPassword.value,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      hintText: "New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          showNewPassword.value ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          showNewPassword.value = !showNewPassword.value;
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0 * 1.5, vertical: 16.0,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .color!
                        .withOpacity(0.08),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 16.0),
              SizedBox(
                width: 160,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: submitUpdate,
                  child: const Text("Save Update"),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}


