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
      // start async load
      () async {
        final stored = await LocalStorageService().getUser();
        user.value = stored;
        AppState.instance.updateUser(stored);
      }();
      return null; // no cleanup required
    }, const []);

    // While user is loading show a loader (or a placeholder)
    if (user.value == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // user is non-null here, safe to read roleName
    final isPm = user.value!.roleName == 'Production Manager';

    return MainLayout(
      title: "Home",
      screenType: isPm ? ScreenType.home_search : ScreenType.home,
      child: AppBottomNavigationBar(),
    );
  }
}
