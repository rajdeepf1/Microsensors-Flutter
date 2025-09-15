// EditUser.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/user_list/repository/sales_managers_user_repository.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';

import '../../../core/api_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/user_model/user_model.dart';
import '../../../models/user_model/user_update_request.dart';
import '../../components/user/profile_pic.dart';
import '../../components/user/user_info_edit_field.dart';

class EditUser extends HookWidget {
  final int userId;
  final String name;
  final String email;
  final String mobileNumber;
  final String roleName;
  final String avatarUrl;
  final bool isActive;
  final FocusNode? nameFocusNode;
  final ValueNotifier<bool>? enableSaveNotifier;

  const EditUser({
    super.key,
    required this.userId,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.roleName,
    required this.avatarUrl,
    required this.isActive,
    this.nameFocusNode,
    this.enableSaveNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(() => GlobalKey<FormState>());


    final repo = useMemoized(() => SalesManagersUserRepository());
    final loading = useState(false);
    final deleteLoading = useState(false);
    final isSwitched = useState(isActive);
    final roleId = useState<int?>(null);
    final pickedImage = useState<File?>(null); // single state for selected image
    final isSaveButtonDisable = useState(true);

    // controllers pre-filled with current user
    final nameCtrl = useTextEditingController(text: name);
    final emailCtrl = useTextEditingController(text: email);
    final phoneCtrl = useTextEditingController(text: mobileNumber);

    // role map
    final Map<String, int> roleMap = {
      "Sales": 2,
      "Production Manager": 3,
    };

    // initialize roleId from roleName
    useEffect(() {
      if (roleMap.containsKey(roleName)) {
        roleId.value = roleMap[roleName];
      }
      return null;
    }, []);

    useEffect(() {
      if (enableSaveNotifier != null) {
        void listener() {
          isSaveButtonDisable.value = !enableSaveNotifier!.value;
        }

        enableSaveNotifier!.addListener(listener);
        return () => enableSaveNotifier!.removeListener(listener);
      }
      return null;
    }, [enableSaveNotifier]);

    useEffect(() {
      if (pickedImage.value != null && enableSaveNotifier != null) {
        enableSaveNotifier!.value = true;  // enable save if an image is picked
      }
      return null;
    }, [pickedImage.value]);

    // Step 1: Pick image
    Future<void> pickImage() async {
      try {
        final res = await FilePicker.platform.pickFiles(type: FileType.image);
        if (res != null && res.files.isNotEmpty && res.files.first.path != null) {
          pickedImage.value = File(res.files.first.path!);
          if (enableSaveNotifier != null) {
            enableSaveNotifier!.value = true;
          }
        }
      } on PlatformException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.message}')),
        );
      } on MissingPluginException {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plugin not available (restart app)')),
        );
      }
    }

    Future<void> submitUpdate() async {
      final name = nameCtrl.text.trim();
      final email = emailCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      final id = roleId.value;
      final isActive = isSwitched.value;

      if (name.isEmpty || email.isEmpty || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Name, Email, and Phone are required")),
        );
        return;
      }

      if (email.isNotEmpty && !Constants.isValidEmail(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email')),
        );
        return;
      }

      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a role")),
        );
        return;
      }

      loading.value = true;
      try {
        final req = UpdateUserForSalesAndManagerRequest(
          userId: userId,
          userName: name,
          email: email,
          phoneNumber: phone,
          roleId: id,
          isActive: isActive,
        );

        final updateRes = await repo.updateUser(req);

        if (updateRes is ApiData<UserResponseModel>) {
          final updatedUser = updateRes.data.data;

          if (updatedUser != null) {
            // upload image if selected
            if (pickedImage.value != null) {
              final uploadRes = await repo.uploadProfileImage(
                updatedUser.userId,
                pickedImage.value!,
              );
              if (uploadRes is ApiData<UserResponseModel>) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User updated with avatar")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("User updated, but image upload failed"),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User updated successfully")),
              );
            }

            //  close screen and tell caller to refresh
            Navigator.of(context).pop(true);
          }
        } else if (updateRes is ApiError<UserResponseModel>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(updateRes.message ?? "Failed to update user"),
            ),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    Future<void> onDeleteUser() async {
      final adminUser = await LocalStorageService().getUser();

      final deletedBy = adminUser?.userId;


      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete user'),
          content: const Text(
              'Are you sure you want to delete this user? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      deleteLoading.value = true;

      debugPrint("Checking----${userId}----deletedBy->${deletedBy}");

      final res = await repo.deleteUser(userId, deletedBy!);

      if (res is ApiData<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data)),
        );
        Navigator.of(context).pop(true); // ✅ refresh user list
      } else if (res is ApiError<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Failed to delete user')),
        );
      }
      deleteLoading.value = false;
    }

    // roles dropdown
    List<DropdownMenuItem<int>> roles = roleMap.entries
        .map(
          (entry) => DropdownMenuItem<int>(
        value: entry.value,
        child: Text(entry.key),
      ),
    )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // <-- Here we pass either the picked file path (preview) or the avatarUrl.
          ProfilePic(
            image: pickedImage.value != null ? pickedImage.value!.path : avatarUrl,
            userName: name,
            imageUploadBtnPress: pickImage,
            isShowPhotoUpload: true,
            isFile: pickedImage.value != null, // 👈 tells ProfilePic to use File
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
                    focusNode: nameFocusNode,
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0 * 1.5,
                        vertical: 16.0,
                      ),
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
                        horizontal: 16.0 * 1.5,
                        vertical: 16.0,
                      ),
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
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0 * 1.5,
                        vertical: 16.0,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                UserInfoEditField(
                  text: "Role",
                  child: DropdownButtonFormField(
                    value: roleId.value,
                    items: roles,
                    icon: const Icon(Icons.expand_more),
                    onChanged: (value) => roleId.value = value,
                    style: TextStyle(
                      color: AppColors.sub_heading_text_color,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Roles',
                      filled: true,
                      fillColor: AppColors.app_blue_color.withOpacity(0.05),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0 * 1.5,
                        vertical: 16.0,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                UserInfoEditField(
                  text: "Active Status",
                  child: Switch(
                    value: isSwitched.value,
                    onChanged: (val) => isSwitched.value = val,
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.greenAccent,
                    inactiveThumbColor: AppColors.app_blue_color,
                    inactiveTrackColor: AppColors.app_blue_color.withOpacity(0.05),
                    trackOutlineColor: MaterialStateProperty.all(
                      AppColors.app_blue_color.withOpacity(0.05),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 70.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: (loading.value || isSaveButtonDisable.value)
                  ? null
                  : submitUpdate,
              child: const Text("Save Update"),
            ),
          ),

          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: Divider(
                  thickness: 1,
                  color: Colors.grey,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "OR",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.text_color,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  thickness: 1,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.delete_button_color,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: deleteLoading.value ? null : onDeleteUser,
              child:
              deleteLoading.value
                  ? const CircularProgressIndicator()
                  : const Text("Delete"),
            ),
          ),
          SizedBox(height: 80),

        ],
      ),
    );
  }
}
