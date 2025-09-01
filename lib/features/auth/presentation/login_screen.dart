import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/gestures.dart';
import '../../../utils/colors.dart';
import '../../../utils/sizes.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

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
                  Image.asset('assets/images/auth_image.png', width: 1000),

                  // Text positioned using Positioned
                  Positioned(
                    top: 550, // adjust vertical position of text
                    left: -250,
                    right: 0,
                    child: const Text(
                      "Login",
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Welcome",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.heading_text_color,
                    ),
                  ),
                  Text(
                    "Login to continue",
                    style: TextStyle(fontSize: 16, color: AppColors.text_color),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.text_color),
                    decoration: InputDecoration(
                      labelText: "Enter Number",
                      labelStyle: TextStyle(color: AppColors.text_color),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.textField_radius,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.phone_android_outlined),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.large_button_horizontal_padding,
                      ),
                      backgroundColor: AppColors.button_color,
                    ),
                    child: Text(
                      "Login",
                      style: TextStyle(color: AppColors.button_text_color),
                    ),
                  ),

                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          color: AppColors.app_blue_color,
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
                          color: AppColors.app_blue_color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  RichText(
                    text: TextSpan(
                      style:  TextStyle(
                        fontSize: 16,
                        color: AppColors.text_color, // default color
                      ),
                      children: [
                         const TextSpan(text: "Signup from "),
                        TextSpan(
                          text: "here",
                          style:  TextStyle(
                            color: AppColors.app_blue_color, // highlighted blue
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              context.push('/signup');
                            },
                        ),

                      ],
                    ),
                  )
,
                  // ElevatedButton(
                  //   onPressed: () {},
                  //   child: const Text("Register"),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
