import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:microsensors/features/components/main_layout/main_layout.dart';
import 'package:url_launcher/url_launcher.dart'; // keep this import
import '../../../utils/colors.dart';

class HelpCenterScreen extends HookWidget {
  const HelpCenterScreen({super.key});

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: Uri.encodeFull('subject=Microsensors App Support'),
    );

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      debugPrint('Could not launch email app');
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(
      scheme: 'tel',
      path: phone,
    );

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      debugPrint('Could not launch phone dialer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    final supportEmail = useState("app.microsensors@gmail.com");
    final supportPhone = useState("+91 00000 00000");

    return MainLayout(title: "Help Center", child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Image.asset('assets/icons/m.png', height: 120),
          const SizedBox(height: 24),
          Text("We're here to help!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          Text(
            "If you’re facing any issues, our support team is just one message away.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 40),
          _ContactCard(
            icon: Icons.email_rounded,
            label: "Email Us",
            value: supportEmail.value,
            color: AppColors.appBlueColor,
            onTap: () => _launchEmail(supportEmail.value),
          ),
          const SizedBox(height: 20),
          _ContactCard(
            icon: Icons.phone_rounded,
            label: "Call Us",
            value: supportPhone.value,
            color: Colors.green,
            onTap: () => _launchPhone(supportPhone.value),
          ),
          const Spacer(),
          Text(
            "© 2025 Microsensors Technologies",
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
          ),
        ],
      ),
    ));
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;

    return Card(
      elevation: 3,
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text(value,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textColor.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
