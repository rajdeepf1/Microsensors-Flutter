import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:microsensors/models/user_model/user_model.dart';
import '../../../core/app_state.dart';
import '../../../core/local_storage_service.dart';
import '../../components/main_layout/main_layout.dart';
import '../../components/bottom_navigation_bar/bottom_navigation_bar.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Load user from local storage once when HomeScreen is created

    final user = useState<UserDataModel?>(null);

    useEffect(() {
      () async {
        final stored = await LocalStorageService().getUser();
        user.value = stored;
        AppState.instance.updateUser(stored);
      }();
      return null; // cleanup not needed
    }, const []);

    return MainLayout(
      title: "Home",
      screenType: user.value!.roleName == 'Production Manager'?ScreenType.home_search:ScreenType.home,
      child: AppBottomNavigationBar(),
    );
  }
}
