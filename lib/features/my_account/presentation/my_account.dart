import 'package:flutter/material.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';

import '../../components/main_layout/main_layout.dart';
import '../../components/user/profile_pic.dart';
import '../../components/user/user_info_edit_field.dart';

class MyAccount extends StatelessWidget {
  const MyAccount({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(title: "My Account", child:
    SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          ProfilePic(
            image: Constants.user_default_image,
            imageUploadBtnPress: () {},
          ),
          const Divider(),
          Form(
            child: Column(
              children: [
                UserInfoEditField(
                  text: "Name",
                  child: TextFormField(
                    initialValue: "Annette Black",
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
                    initialValue: "annette@gmail.com",
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
                    initialValue: "(000) 000-0000",
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
                  text: "Address",
                  child: TextFormField(
                    initialValue: "New York, NVC",
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
                    obscureText: true,
                    initialValue: "demopass",
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      suffixIcon: const Icon(
                        Icons.visibility_off,
                        size: 20,
                      ),
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
                  text: "New Password",
                  child: TextFormField(
                    style: TextStyle(color: AppColors.sub_heading_text_color),
                    decoration: InputDecoration(
                      hintText: "New Password",
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
                  onPressed: () {},
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


