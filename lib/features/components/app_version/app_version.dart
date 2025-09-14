import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionWidget extends StatelessWidget {
  const AppVersionWidget({super.key});

  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return "${info.version} (${info.buildNumber})"; // e.g. "1.2.0 (12)"
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getVersion(),
      builder: (context, snapshot) {
        // Reserve a fixed height so widget is always visible in layout
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text("Checking version...", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              "Version: —",
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        final version = snapshot.data ?? '—';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            "Version $version",
            style: TextStyle(color: Colors.grey[600]),
          ),
        );
      },
    );
  }
}
