import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';
import '../../../core/api_state.dart';
import '../../../models/user_model/user_model.dart';
import '../../components/user/profile_pic.dart';
import '../../components/user/user_info_edit_field.dart';
import '../repository/add_user_repository.dart';

class AddUser extends HookWidget {
  const AddUser({super.key});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final passCtrl = useTextEditingController();
    final confpassCtrl = useTextEditingController();

    final pickedImage = useState<File?>(null);
    final loading = useState(false);
    final roleId = useState<int?>(null);
    final showPassword = useState(false);
    final showConfPassword = useState(false);
    final isSwitched = useState(true);

    final repo = useMemoized(() => AddUserRepository());

    // Step 1: Pick image
    Future<void> pickImage() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      pickedImage.value = File(path);
    }

    // Step 2: Add user and then upload image
    Future<void> addUser() async {
      final name = nameCtrl.text.trim();
      final email = emailCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      final pass = passCtrl.text.trim();
      final confpass = confpassCtrl.text.trim();
      final id = roleId.value;
      final isActive = isSwitched.value;

      if (name.isEmpty ||
          email.isEmpty ||
          phone.isEmpty ||
          pass.isEmpty ||
          confpass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All fields are required")),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please select a role")));
        return;
      }

      if (pass != confpass) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid password')),
        );
        return;
      }

      loading.value = true;
      try {
        final createRes = await repo.createUser(
          username: name,
          email: email,
          mobileNumber: phone,
          password: pass,
          roleId: id,
          is_active: isActive
        );

        if (createRes is ApiData<UserResponseModel>) {
          final createdUser = createRes.data.data;
          if (createdUser != null) {
            // upload image if selected
            if (pickedImage.value != null) {
              final uploadRes = await repo.uploadProfileImage(
                createdUser.userId,
                pickedImage.value!,
              );
              if (uploadRes is ApiData<UserResponseModel>) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User created with avatar")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("User created, but image upload failed"),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User created successfully")),
              );
            }
            context.pop();
          }
        } else if (createRes is ApiError<UserResponseModel>) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(createRes.message ?? "Failed to create user"),
            ),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    final Map<String, int> roleMap = {
      //"Admin": 1,
      "Sales": 2,
      "Production Manager": 3,
    };

    List<DropdownMenuItem<int>> roles =
        roleMap.entries
            .map(
              (entry) => DropdownMenuItem<int>(
                value: entry.value,
                child: Text(entry.key),
              ),
            )
            .toList();

    return MainLayout(
      title: "Add User",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            ProfilePic(
              image: pickedImage.value?.path ?? '',
              userName: "User",
              imageUploadBtnPress: pickImage,
              isShowPhotoUpload: true,
              placeHolder: Image.asset("assets/images/user.png"),
            ),
            const Divider(),
            Form(
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
                    text: "Password",
                    child: TextFormField(
                      controller: passCtrl,
                      obscureText: !showPassword.value,
                      style: TextStyle(color: AppColors.sub_heading_text_color),
                      decoration: InputDecoration(
                        hintText: "Password",
                        filled: true,
                        fillColor: AppColors.app_blue_color.withOpacity(0.05),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword.value ? Icons.visibility : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            showPassword.value = !showPassword.value;
                          },
                        ),
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
                    text: "Confirm Password",
                    child: TextFormField(
                      controller: confpassCtrl,
                      obscureText: !showConfPassword.value,
                      style: TextStyle(color: AppColors.sub_heading_text_color),
                      decoration: InputDecoration(
                        hintText: "Confirm Password",
                        filled: true,
                        fillColor: AppColors.app_blue_color.withOpacity(0.05),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showConfPassword.value ? Icons.visibility : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            showConfPassword.value = !showConfPassword.value;
                          },
                        ),
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
                    text: "Active Status",
                    child: Switch(
                      value: isSwitched.value,
                      onChanged: (val) => isSwitched.value = val,
                      activeThumbColor: Colors.green,
                      activeTrackColor: Colors.greenAccent,
                      // track color when ON
                      inactiveThumbColor: AppColors.app_blue_color,
                      // thumb color when OFF
                      inactiveTrackColor: AppColors.app_blue_color
                          .withOpacity(0.05),
                      // track color when OFF
                      trackOutlineColor: MaterialStateProperty.all(
                        AppColors.app_blue_color.withOpacity(0.05),
                      ),
                    ),
                  ),


                ],
              ),
            ),
            const SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                onPressed: loading.value ? null : addUser,
                child:
                    loading.value
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Add User"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
