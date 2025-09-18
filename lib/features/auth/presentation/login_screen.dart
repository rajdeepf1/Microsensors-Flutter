import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/models/otp/OTPResponse.dart';
import '../../../core/local_storage_service.dart';
import '../../../utils/colors.dart';
import '../../../utils/sizes.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import 'package:microsensors/core/api_state.dart';
import '../../components/edit_text_field/EditTextField.dart';
import '../data/auth_repository.dart';

class LoginScreen extends HookWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => AuthRepository());

    final showOtpFields = useState(false);
    final phoneController = useTextEditingController();

    // Controllers & FocusNodes for OTP
    final otpControllers = List.generate(4, (_) => useTextEditingController());
    final otpFocusNodes = List.generate(4, (_) => useFocusNode());

    final loading = useState<bool>(false);
    final foundUser = useState<UserDataModel?>(null);

    void handleOtpInput(String value, int index) {
      if (value.isNotEmpty && index < 3) {
        FocusScope.of(context).requestFocus(otpFocusNodes[index + 1]);
      } else if (value.isEmpty && index > 0) {
        FocusScope.of(context).requestFocus(otpFocusNodes[index - 1]);
      }
    }

    Future<void> startLogin() async {
      final phone = phoneController.text.trim();
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a phone number')),
        );
        return;
      }

      loading.value = true;
      try {
        final res = await repo.fetchEmailByPhone(phone);
        // res is ApiState<UserResponseModel>
        if (res is ApiData<UserResponseModel>) {
          final wrapper = res.data; // UserResponseModel (the wrapper)
          // wrapper.success, wrapper.statusCode, wrapper.error, wrapper.data available
          if (wrapper.success == true && wrapper.data != null) {
            final userData = wrapper.data!; // UserDataModel
            // store the UserDataModel for OTP verification step
            foundUser.value = userData;

            showOtpFields.value = true;
            FocusScope.of(context).requestFocus(otpFocusNodes[0]);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP requested. Please check your email.'),
              ),
            );
          } else {
            // server says success=false or data is null
            final err =
                wrapper.error?.toString() ??
                'No user object returned by server';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(err)));
          }
        } else if (res is ApiError<UserResponseModel>) {
          // ApiError should expose message / error fields
          final msg = res.message;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Login failed: $msg')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unexpected server response')),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    Future<void> verifyOtpAndSave() async {
      final otp = otpControllers.map((c) => c.text).join();
      if (otp.length < 4) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter 4-digit OTP')));
        return;
      }
      if (foundUser.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user to verify — request OTP first'),
          ),
        );
        return;
      }

      loading.value = true;
      try {
        // foundUser is UserDataModel
        final userData = foundUser.value!;
        final res = await repo.verifyOtp(userData, otp);

        // res is ApiState<OtpResponse>
        if (res is ApiData<OtpResponse>) {
          final otpResp = res.data;
          if (otpResp.success &&
              (otpResp.statusCode == 200 || otpResp.statusCode == 201)) {
            // Save the user (UserDataModel) to local storage
            try {
              await LocalStorageService().saveUser(userData);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save user locally: $e')),
              );
              // optional: return; // if saving is critical
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Welcome ${userData.username}')),
              );
              context.go('/home');
            }
          } else {
            final msg =
                otpResp.error ?? otpResp.data ?? 'OTP verification failed';
            await LocalStorageService().removeUser();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
        } else if (res is ApiError<OtpResponse>) {
          final msg = res.message;
          await LocalStorageService().removeUser();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        } else {
          await LocalStorageService().removeUser();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unexpected verify response')),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    Future<void> resendOtp() async {
      if (foundUser.value == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No user to resend OTP.')));
        return;
      }
      loading.value = true;
      try {
        final res = await repo.sendOtp(foundUser.value!);
        if (res is ApiData<bool> && res.data == true) {
          for (final c in otpControllers) {
            c.clear();
          }
          FocusScope.of(context).requestFocus(otpFocusNodes[0]);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('OTP resent')));
        } else if (res is ApiError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Resend failed: $res')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unexpected resend response')),
          );
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
                    SizedBox(height: 100),
                    Text(
                      "Welcome",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headingTextColor,
                      ),
                    ),
                    Text(
                      "Login to continue",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textColor,
                      ),
                    ),
                    const SizedBox(height: 40),

                    EditTextField(
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: AppColors.subHeadingTextColor,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          hint: Text("Enter Number"),
                          prefixIcon: const Icon(Icons.phone_android_outlined),
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

                    const SizedBox(height: 20),

                    if (loading.value)
                      const CircularProgressIndicator()
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!showOtpFields.value) ...[
                            ElevatedButton(
                              onPressed: startLogin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal:
                                      AppSizes.largeButtonHorizontalPadding,
                                ),
                                backgroundColor: AppColors.buttonColor,
                              ),
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: AppColors.buttonTextColor,
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                4,
                                (index) => SizedBox(
                                  width: 50,
                                  child: EditTextField(
                                    child: TextFormField(
                                      controller: otpControllers[index],
                                      focusNode: otpFocusNodes[index],
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      keyboardType: TextInputType.number,
                                      onChanged:
                                          (value) =>
                                              handleOtpInput(value, index),
                                      style: TextStyle(
                                        color: AppColors.subHeadingTextColor,
                                        fontSize: 20,
                                        // bigger font for OTP digits (optional)
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        counterText: "",
                                        fillColor: AppColors.appBlueColor
                                            .withValues(alpha: 0.05),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14.0,
                                              vertical: 14.0,
                                            ),
                                        border: const OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(15),
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
                              onPressed: verifyOtpAndSave,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal:
                                      AppSizes.largeButtonHorizontalPadding,
                                ),
                                backgroundColor: AppColors.buttonColor,
                              ),
                              child: Text(
                                "Verify",
                                style: TextStyle(
                                  color: AppColors.buttonTextColor,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: resendOtp,
                              child: const Text('Resend OTP'),
                            ),
                          ],
                        ],
                      ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 1,
                            color: AppColors.appBlueColor,
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
                            color: AppColors.appBlueColor,
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
                          color: AppColors.textColor, // default color
                        ),
                        children: [
                          const TextSpan(
                            text: "Login using email-id & password",
                          ),
                          TextSpan(
                            text: " Click Here",
                            style: TextStyle(
                              color: AppColors.appBlueColor,
                              // highlighted blue
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    context.push('/email-login');
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
