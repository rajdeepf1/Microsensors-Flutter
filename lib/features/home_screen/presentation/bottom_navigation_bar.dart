import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class AppBottomNavigationBar extends HookWidget {
  @override
  Widget build(BuildContext context) {
    // useState replaces setState and StatefulWidget
    final currentIndex = useState(0);

    final pages = [
      Center(child: Text("🏠 Home", style: TextStyle(fontSize: 24))),
      Center(child: Text("👤 Profile", style: TextStyle(fontSize: 24))),
    ];

    return Scaffold(
      body: pages[currentIndex.value],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex.value,
        onTap: (index) {
          currentIndex.value = index; // updates UI
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
