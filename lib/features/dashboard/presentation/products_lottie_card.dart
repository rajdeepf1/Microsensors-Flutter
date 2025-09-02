import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:microsensors/utils/colors.dart';

class ProductsLottieCard extends StatelessWidget {
  final String lottiePath; // asset path of Lottie animation
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ProductsLottieCard({
    super.key,
    required this.lottiePath,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: AppColors.card_color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Background Lottie animation
            Lottie.asset(
              lottiePath,
              fit: BoxFit.contain,
              height: 150,
              width: double.infinity,
              repeat: true,
              animate: true,
            ),

            // Dark overlay for better readability
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),

        // Foreground (icon + label + arrow)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side: icon + label in a column
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 30, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Right side: arrow icon
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),

      ),
          ],
        ),
      ),
    );
  }
}
