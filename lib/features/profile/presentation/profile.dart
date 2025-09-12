import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/utils/colors.dart';
import '../../../core/api_state.dart';
import '../../../core/app_state.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/user_model/user_model.dart';
import '../../../utils/constants.dart';
import '../../components/smart_image/smart_image.dart';
import '../repository/user_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const ProfilePic(),
            const SizedBox(height: 20),
            ProfileMenu(
              text: "My Account",
              icon: Icons.person_outline_rounded,
              press: () => {
                context.push("/my-account")
              },
            ),
            ProfileMenu(
              text: "Notifications",
              icon: Icons.notifications_none_outlined,
              press: () {
                context.push("/notification");
              },
            ),
            ProfileMenu(
              text: "Settings",
              icon: Icons.settings_applications_outlined,
              press: () {},
            ),
            ProfileMenu(
              text: "Help Center",
              icon: Icons.help_center_outlined,
              press: () {},
            ),
            ProfileMenu(
              text: "Log Out",
              icon: Icons.logout_outlined,
              press: () async {
                print("hiiiiii");
                await LocalStorageService().removeUser();
                context.go("/login");
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePic extends HookWidget {
  const ProfilePic({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final currentUser = useValueListenable(AppState.instance.currentUser);

    final repo = useMemoized(() => UserRepository());
    final picked = useState<File?>(null);
    final loading = useState(false);
    final message = useState<String?>(null);

    final user = currentUser;
    final username = user?.username ?? "User";
    final imageUrl = user?.userImage;

    Future<void> pickAndUpload() async {
      try {
        final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
        if (res == null || res.files.isEmpty) return;
        final path = res.files.first.path;
        if (path == null) return;

        final file = File(path);
        picked.value = file;

        loading.value = true;
        final apiRes = await repo.uploadProfileImage(user!.userId, file);

        if (apiRes is ApiData<UserResponseModel>) {
          message.value = 'Uploaded';
          // Save updated user to SharedPreferences
          final updatedUser = apiRes.data.data; // UserDataModel inside UserResponseModel
          if (updatedUser != null) {
            await LocalStorageService().saveUser(updatedUser);
            // Broadcast to app listeners
            AppState.instance.updateUser(updatedUser);
          }
        } else if (apiRes is ApiError<UserResponseModel>) {
          message.value = apiRes.message ?? apiRes.error?.toString() ?? 'Upload failed';
        } else {
          message.value = 'Unexpected response';
        }
      } on PlatformException catch (e) {
        message.value = 'Platform error: ${e.message}';
      } on MissingPluginException {
        message.value = 'Plugin not available (restart app)';
      } finally {
        loading.value = false;
      }
    }





    return SizedBox(
      height: 115,
      width: 115,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (loading.value)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            SmartImage(
              imageUrl: imageUrl,
              baseUrl: Constants.apiBaseUrl,
              width: 115,
              height: 115,
              shape: ImageShape.circle,
              username: username,
            ),
          Positioned(
            right: -16,
            bottom: 0,
            child: SizedBox(
              height: 46,
              width: 46,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: const BorderSide(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFF5F6F9),
                ),
                onPressed: pickAndUpload,
                child: SvgPicture.string(Constants.cameraIcon),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({
    Key? key,
    required this.text,
    required this.icon,
    this.press,
  }) : super(key: key);

  final String text;
  final IconData icon;
  final VoidCallback? press;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.app_blue_color,
          padding: const EdgeInsets.all(20),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: const Color(0xFFF5F6F9),
        ),
        onPressed: press,
        child: Row(
          children: [
            Icon(icon,size: 22,),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF757575),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF757575),
            ),
          ],
        ),
      ),
    );
  }
}


