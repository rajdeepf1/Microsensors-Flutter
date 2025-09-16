// lib/features/auth/ui/login_screen.dart
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/models/otp/OTPResponse.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/local_storage_service.dart';
import '../../../utils/colors.dart';
import '../../../utils/sizes.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/core/api_state.dart';

import '../../add_product/presentation/add_product.dart';
import '../../components/edit_text_field/EditTextField.dart';
import '../data/auth_repository.dart';

class EmailPasswordLoginScreen extends HookWidget {
  const EmailPasswordLoginScreen({super.key});

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {

    final repo = useMemoized(() => AuthRepository());
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final loading = useState<bool>(false);
    final showPassword = useState(false);

    Future<void> doLogin() async {
      final email = emailController.text.trim();
      final password = passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter email and password')),
        );
        return;
      }

      if (!isValidEmail(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
        return;
      }

      loading.value = true;
      try {
        final res = await repo.loginWithEmailPassword(email, password);

        if (res is ApiData<UserResponseModel>) {
          final wrapper = res.data;
          if (wrapper.success && wrapper.data != null) {
            final user = wrapper.data!;

            // Save user
            await LocalStorageService().saveUser(user);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Welcome ${user.username}')),
            );
            if (context.mounted) context.go('/home');
          } else {
            final msg = wrapper.error?.toString() ?? 'Login failed';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        } else if (res is ApiError<UserResponseModel>) {
          final msg = res.message ?? res.error?.toString() ?? 'Login failed';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      } finally {
        loading.value = false;
      }
    }



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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 100,),
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
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.text_color,
                      ),
                    ),
                    const SizedBox(height: 40),
                    EditTextField(
                      child: TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppColors.sub_heading_text_color),
                        decoration: InputDecoration(
                          filled: true,
                          hint: Text("Enter an email"),
                          prefixIcon: const Icon(Icons.email_outlined),
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
                    const SizedBox(height: 20),
                    EditTextField(
                      child: TextFormField(
                        controller: passwordController,
                        obscureText: !showPassword.value,
                        keyboardType: TextInputType.visiblePassword,
                        style: TextStyle(color: AppColors.sub_heading_text_color),
                        decoration: InputDecoration(
                          filled: true,
                          hint: Text("Enter password"),
                          prefixIcon: const Icon(Icons.password),
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
                              horizontal: 16.0 * 1.5, vertical: 16.0),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (loading.value)
                      const CircularProgressIndicator()
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            ElevatedButton(
                              onPressed: doLogin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal:
                                      AppSizes.large_button_horizontal_padding,
                                ),
                                backgroundColor: AppColors.button_color,
                              ),
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: AppColors.button_text_color,
                                ),
                              ),
                            ),
                          ]
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

                    // SizedBox(height: 20),
                    // RichText(
                    //   text: TextSpan(
                    //     style: TextStyle(
                    //       fontSize: 16,
                    //       color: AppColors.text_color, // default color
                    //     ),
                    //     children: [
                    //       const TextSpan(text: "Not an user! signup from "),
                    //       TextSpan(
                    //         text: "Here",
                    //         style: TextStyle(
                    //           color: AppColors.app_blue_color,
                    //           // highlighted blue
                    //           fontWeight: FontWeight.bold,
                    //         ),
                    //         recognizer:
                    //             TapGestureRecognizer()
                    //               ..onTap = () {
                    //                 context.push('/signup');
                    //               },
                    //       ),
                    //     ],
                    //   ),
                    // ),

                    SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.text_color, // default color
                        ),
                        children: [
                          const TextSpan(text: "Login using OTP"),
                          TextSpan(
                            text: " Click Here",
                            style: TextStyle(
                              color: AppColors.app_blue_color,
                              // highlighted blue
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer:
                            TapGestureRecognizer()
                              ..onTap = () {
                                context.go('/login');
                              },
                          ),
                        ],
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
