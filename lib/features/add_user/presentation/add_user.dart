import 'package:flutter/material.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:microsensors/utils/colors.dart';
import 'package:microsensors/utils/constants.dart';

import '../../components/user/profile_pic.dart';
import '../../components/user/user_info_edit_field.dart';

class AddUser extends StatelessWidget {
  const AddUser({super.key});

  @override
  Widget build(BuildContext context) {

    List<DropdownMenuItem<String>>? countries = [
      "Admin",
      "Sales",
      'Production Manager',
    ].map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(value: value, child: Text(value));
    }).toList();

    return
     MainLayout(title: "Add User", child:
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            ProfilePic(
              image: Constants.user_default_image,
              userName: "",
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
                    text: "Role",
                    child: DropdownButtonFormField(
                      items: countries,
                      icon: const Icon(Icons.expand_more),
                      onSaved: (country) {
                        // save it
                      },
                      onChanged: (value) {},
                      style: TextStyle(color: AppColors.sub_heading_text_color,fontWeight: FontWeight.bold),
                      decoration:  InputDecoration(
                        hintText: 'Roles',
                        filled: true,
                        fillColor: AppColors.app_blue_color.withOpacity(0.05),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0 * 1.5, vertical: 16.0),
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
                      style: TextStyle(color: AppColors.sub_heading_text_color),
                      decoration: InputDecoration(
                        hintText: "Password",
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
                    child: const Text("Add User"),
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


