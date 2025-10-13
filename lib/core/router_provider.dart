import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:microsensors/features/add_product/presentation/add_product.dart';
import 'package:microsensors/features/add_user/presentation/add_user.dart';
import 'package:microsensors/features/auth/presentation/email_password_login_screen.dart';
import 'package:microsensors/features/dashboard/presentation/order_activities.dart';
import 'package:microsensors/features/my_account/presentation/my_account.dart';
import 'package:microsensors/features/notification/presentation/notification.dart';
import 'package:microsensors/features/product_list/presentation/product_list.dart';
import 'package:microsensors/features/production_user_dashboard/presentation/pm_history_search.dart';
import 'package:microsensors/features/sales_user_dashboard/presentation/sales_orders_list.dart';
import 'package:microsensors/features/user_list/presentation/users_list.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/help_center/help_center_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/sales_user_dashboard/presentation/add_orders.dart';
import '../features/splash/presentation/splash_screen.dart';



final routerProvider = Provider<GoRouter>((ref) {
  //final isLoggedIn = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/email-login',
        builder: (context, state) => const EmailPasswordLoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
        //redirect: (context, state) => !isLoggedIn ? '/login' : null,
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersList(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductList(),
      ),
      GoRoute(
        path: '/my-account',
        builder: (context, state) => const MyAccount(),
      ),
      GoRoute(
        path: '/notification',
        builder: (context, state) => const Notification(),
      ),
      GoRoute(
        path: '/add-user',
        builder: (context, state) => const AddUser(),
      ),
      GoRoute(
        path: '/add-product',
        builder: (context, state) => const AddProduct(),
      ),
      GoRoute(
        path: '/add-orders',
        builder: (context, state) => const AddOrders(),
      ),
      GoRoute(
        path: '/sales-orders-list',
        builder: (context, state) => const SalesOrdersList(),
      ),
      GoRoute(
        path: '/production-manager-history-search',
        builder: (context, state) => ProductionManagerHistorySearch(),
      ),
      GoRoute(
        path: '/order-activities',
        builder: (context, state) => OrderActivities(),
      ),
      GoRoute(
        path: '/help-center',
        builder: (context, state) => HelpCenterScreen(),
      ),
    ],
  );
});
