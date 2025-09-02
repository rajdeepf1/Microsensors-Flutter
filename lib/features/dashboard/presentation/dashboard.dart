import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:microsensors/features/dashboard/presentation/stats_card.dart';
import 'package:microsensors/utils/sizes.dart';
import '../../../utils/colors.dart';
import 'products_lottie_card.dart';
import 'users_lottie_card.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';


class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Scrollbar(
        thumbVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.right,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Stats",
                style: TextStyle(
                  color: AppColors.heading_text_color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                ),
              ),

              // Horizontal scroll stats cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatsCard(
                      title: "Users",
                      value: "120",
                      icon: Icons.person,
                      color: Colors.blue,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "Orders",
                      value: "45",
                      icon: Icons.shopping_cart,
                      color: Colors.green,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "Revenue",
                      value: "\$12k",
                      icon: Icons.attach_money,
                      color: Colors.orange,
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    StatsCard(
                      title: "Products",
                      value: "230",
                      icon: Icons.inventory,
                      color: Colors.purple,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Text(
                "Users",
                style: TextStyle(
                  color: AppColors.heading_text_color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                ),
              ),
              UsersLottieCard(
                lottiePath: "assets/animations/adduser.json",
                icon: Icons.person_pin_outlined,
                label: "Users",
                onTap: () {
                  print("Users Clicked");
                  context.push("/users");
                },
              ),

              const SizedBox(height: 20),

              Text(
                "Products",
                style: TextStyle(
                  color: AppColors.heading_text_color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                ),
              ),
              ProductsLottieCard(
                lottiePath: "assets/animations/addproduct.json",
                icon: Icons.file_copy_outlined,
                label: "Products",
                onTap: () {
                  print("Add Product Clicked");
                  context.push("/products");
                },
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColors.fab_foreground_icon_color,
        overlayOpacity: 0,
        spacing: 10,
        children: [
          SpeedDialChild(
            child: Icon(Icons.person_add,size: 28,color: AppColors.fab_foreground_icon_color,),
            label: "Add User",
            labelStyle: TextStyle(color: AppColors.heading_text_color),
            backgroundColor: Colors.blue,
            onTap: () {
              print("Add User Clicked");
              context.push("/add-user");
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.add_box,size: 28,color: AppColors.fab_foreground_icon_color,),
            label: "Add Product",
            labelStyle: TextStyle(color: AppColors.heading_text_color),
            backgroundColor: Colors.green,
            onTap: () {
              print("Add Product Clicked");
              context.push("/add-product");
            },
          ),
        ],
      ),

    );
  }
}
