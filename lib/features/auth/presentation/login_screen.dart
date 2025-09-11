import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/gestures.dart';
import '../../../utils/colors.dart';
import '../../../utils/sizes.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOtpFields = useState(false);

    // Controllers & FocusNodes for OTP
    final otpControllers = List.generate(4, (_) => useTextEditingController());
    final otpFocusNodes = List.generate(4, (_) => useFocusNode());

    void handleOtpInput(String value, int index) {
      if (value.isNotEmpty && index < 3) {
        // Move to next field
        FocusScope.of(context).requestFocus(otpFocusNodes[index + 1]);
      } else if (value.isEmpty && index > 0) {
        // Move back if deleting
        FocusScope.of(context).requestFocus(otpFocusNodes[index - 1]);
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

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!showOtpFields.value) ...[
                        /// Normal Login Button
                        ElevatedButton(
                          onPressed: () {
                            showOtpFields.value = true;
                            FocusScope.of(context).requestFocus(
                              otpFocusNodes[0],
                            ); // auto-focus first field
                          },
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
                      ] else ...[
                        /// 4 OTP TextFields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                                (index) => SizedBox(
                              width: 50,
                              child: TextField(
                                controller: otpControllers[index],
                                focusNode: otpFocusNodes[index],
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                keyboardType: TextInputType.number,
                                onChanged:
                                    (value) => handleOtpInput(value, index),
                                decoration: const InputDecoration(
                                  counterText: "",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(
                                        AppSizes.textField_radius,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        /// Verify Button
                        ElevatedButton(
                          onPressed: () {
                            final otp =
                            otpControllers.map((c) => c.text).join();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Entered OTP: $otp")),
                            );
                            context.go("/home");
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal:
                              AppSizes.large_button_horizontal_padding,
                            ),
                            backgroundColor: AppColors.button_color,
                          ),
                          child: Text(
                            "Verify",
                            style: TextStyle(
                              color: AppColors.button_text_color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}