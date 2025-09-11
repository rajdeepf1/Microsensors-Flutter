import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../utils/colors.dart';
import '../../../utils/sizes.dart';

class SignUpScreen extends HookConsumerWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Transform.translate(
            offset: const Offset(0, -200), // move image up
            child: FittedBox(
              fit: BoxFit.none,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background image
                  Image.asset(
                    'assets/images/auth_image.png',
                    width: 1000,
                  ),

                  // Text positioned using Positioned
                  Positioned(
                    top:550, // adjust vertical position of text
                    left: -250,
                    right: 0,
                    child: const Text(
                      "Signup",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),


          // Foreground content
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 200),
                    TextField(
                      keyboardType: TextInputType.name,
                      style: TextStyle(color: AppColors.text_color),
                      decoration: InputDecoration(
                        labelText: "Enter Full Name",
                        labelStyle: TextStyle(color: AppColors.text_color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.textField_radius),
                        ),
                        prefixIcon: const Icon(Icons.person_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: AppColors.text_color),
                      decoration: InputDecoration(
                        labelText: "Enter Email",
                        labelStyle: TextStyle(color: AppColors.text_color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.textField_radius),
                        ),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      keyboardType: TextInputType.visiblePassword,
                      style: TextStyle(color: AppColors.text_color),
                      decoration: InputDecoration(
                        labelText: "Enter Password",
                        labelStyle: TextStyle(color: AppColors.text_color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.textField_radius),
                        ),
                        prefixIcon: const Icon(Icons.password_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.text_color),
                      decoration: InputDecoration(
                        labelText: "Enter Number",
                        labelStyle: TextStyle(color: AppColors.text_color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.textField_radius),
                        ),
                        prefixIcon: const Icon(Icons.phone_android_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.large_button_horizontal_padding,
                        ),
                        backgroundColor: AppColors.button_color,
                      ),
                      child: Text(
                        "Signup",
                        style: TextStyle(color: AppColors.button_text_color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}