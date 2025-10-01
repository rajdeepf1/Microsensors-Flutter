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
import '../../my_account/repository/account_repository.dart';

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

    final accountRepo = useMemoized(() => AccountRepository());


    final showCurrentPassword = useState(false);
    final showNewPassword = useState(false);

    final currentPwdLoading = useState<bool>(false);
    final currentPwdError = useState<String?>(null);


    final repo = useMemoized(() => SalesManagersUserRepository());
    final loading = useState(false);
    final deleteLoading = useState(false);
    final isSwitched = useState(isActive);
    final roleId = useState<int?>(null);
    final pickedImage = useState<File?>(null); // selected image preview

    // This flag determines whether fields are editable.
    final isEditing = useState<bool>(false);

    // controllers pre-filled with current user
    final nameCtrl = useTextEditingController(text: name);
    final emailCtrl = useTextEditingController(text: email);
    final phoneCtrl = useTextEditingController(text: mobileNumber);

    final currentPasswordCtrl = useTextEditingController();
    final newPassCtrl = useTextEditingController();


    Future<void> fetchCurrentPassword() async {
      if (userId == null) return;
      currentPwdLoading.value = true;
      currentPwdError.value = null;
      try {
        final res = await accountRepo.fetchUserCurrentPassword(userId);
        if (res is ApiData<String>) {
          currentPasswordCtrl.text = res.data;
        } else if (res is ApiError<String>) {
          currentPasswordCtrl.text = '';
          currentPwdError.value = res.message ?? 'Failed to fetch password';
        } else {
          currentPasswordCtrl.text = '';
          currentPwdError.value = 'Unexpected response';
        }
      } catch (e) {
        currentPasswordCtrl.text = '';
        currentPwdError.value = e.toString();
      } finally {
        currentPwdLoading.value = false;
      }
    }

    useEffect(() {
      // fetch once when widget mounts and when current user changes
      fetchCurrentPassword();
      return null; // no cleanup
    }, [userId]);


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

    // Listen to parent notifier (the external Edit button). When parent sets it true,
    // we enable editing. When parent sets it false, we disable editing and reset UI if needed.
    useEffect(() {
      if (enableSaveNotifier != null) {
        void listener() {
          final val = enableSaveNotifier!.value;
          isEditing.value = val;
          // if parent enabled and passed focus request via nameFocusNode, parent already requests focus
          // nothing more is needed here
        }

        enableSaveNotifier!.addListener(listener);
        // initialize local isEditing from current notifier value
        isEditing.value = enableSaveNotifier!.value;
        return () => enableSaveNotifier!.removeListener(listener);
      }
      return null;
    }, [enableSaveNotifier]);

    // Step 1: Pick image - allow only when editing (parent toggles editing)
    Future<void> pickImage() async {
      if (!isEditing.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tap Edit to enable image upload')),
        );
        return;
      }

      try {
        final res = await FilePicker.platform.pickFiles(type: FileType.image);
        if (res != null && res.files.isNotEmpty && res.files.first.path != null) {
          pickedImage.value = File(res.files.first.path!);
          // ensure parent Save state is enabled (if parent has provided notifier)
          if (enableSaveNotifier != null) enableSaveNotifier!.value = true;
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
      final isActiveLocal = isSwitched.value;

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
          isActive: isActiveLocal,
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

            // reset editing state and notify parent to disable Save
            isEditing.value = false;
            if (enableSaveNotifier != null) enableSaveNotifier!.value = false;
            Navigator.of(context).pop(true); // tell parent to refresh
          }
        } else if (updateRes is ApiError<UserResponseModel>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(updateRes.message),
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

      debugPrint("Checking----$userId----deletedBy->$deletedBy");

      final res = await repo.deleteUser(userId, deletedBy!);

      if (res is ApiData<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data)),
        );
        Navigator.of(context).pop(true); // ✅ refresh user list
      } else if (res is ApiError<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
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

    // true if we can save: either editing was toggled on OR user picked an image
    final canSave = isEditing.value || pickedImage.value != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // No Edit/Cancel button here — your AppBar edit icon controls editing via enableSaveNotifier.

          // Profile pic preview (uses picked file path if present)
          ProfilePic(
            image: pickedImage.value != null ? pickedImage.value!.path : avatarUrl,
            userName: name,
            imageUploadBtnPress: pickImage,
            isShowPhotoUpload: true,
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
                    enabled: isEditing.value,
                    style: TextStyle(color: AppColors.subHeadingTextColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
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
                    enabled: isEditing.value,
                    style: TextStyle(color: AppColors.subHeadingTextColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
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
                    enabled: isEditing.value,
                    style: TextStyle(color: AppColors.subHeadingTextColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
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
                  child: AbsorbPointer(
                    absorbing: !isEditing.value,
                    child: DropdownButtonFormField<int>(
                      initialValue: roleId.value,
                      items: roles,
                      icon: const Icon(Icons.expand_more),
                      onChanged: (value) {
                        if (isEditing.value) roleId.value = value;
                      },
                      style: TextStyle(
                        color: AppColors.subHeadingTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Roles',
                        filled: true,
                        fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
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
                ),

                UserInfoEditField(
                  text: "Password",
                  child: TextFormField(
                    controller: currentPasswordCtrl,
                    readOnly: true,
                    obscureText: !showCurrentPassword.value, // toggle visibility
                    style: TextStyle(color: AppColors.subHeadingTextColor),
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(
                          showCurrentPassword.value ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          showCurrentPassword.value = !showCurrentPassword.value;
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.appBlueColor.withValues(alpha: 0.05),
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
                  text: "Active Status",
                  child: Switch(
                    value: isSwitched.value,
                    onChanged: isEditing.value ? (val) => isSwitched.value = val : null,
                    activeThumbColor: Colors.green,
                    activeTrackColor: Colors.greenAccent,
                    inactiveThumbColor: AppColors.appBlueColor,
                    inactiveTrackColor: AppColors.appBlueColor.withValues(alpha: 0.05),
                    trackOutlineColor: WidgetStateProperty.all(
                      AppColors.appBlueColor.withValues(alpha: 0.05),
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
              onPressed: (loading.value || !canSave) ? null : submitUpdate,
              child: loading.value ? const CircularProgressIndicator() : const Text("Save Update"),
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
                    color: AppColors.textColor,
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
                backgroundColor: AppColors.deleteButtonColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: deleteLoading.value ? null : onDeleteUser,
              child: deleteLoading.value ? const CircularProgressIndicator() : const Text("Delete"),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
