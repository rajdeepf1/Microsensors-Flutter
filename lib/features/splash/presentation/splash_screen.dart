import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/local_storage_service.dart';
import '../../../models/user_model/user_model.dart';
import '../../auth/providers/auth_providers.dart';

class SplashScreen extends HookConsumerWidget {


  const SplashScreen({super.key});



  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final storage = LocalStorageService();

    final controller = useMemoized(
          () => VideoPlayerController.asset("assets/videos/splash.mp4"),
    );
    final videoPlayer = useState<VideoPlayerController?>(null);


    useEffect(() {
      controller.initialize().then((_) {
        videoPlayer.value = controller;
        controller.play();
      });
      Future.delayed(const Duration(seconds: 3), () async {
        final UserModel? user = await storage.getUser();
        if (user != null) {
          // navigate to home
          context.go('/home');
        } else {
          // navigate to login
          context.go('/login');
        }
      });
      return null;
    }, []);

    return Scaffold(
      body: Center(
        child: videoPlayer.value != null && videoPlayer.value!.value.isInitialized
            ? AspectRatio(
          aspectRatio: videoPlayer.value!.value.aspectRatio,
          child:  VideoPlayer(videoPlayer.value!),
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}