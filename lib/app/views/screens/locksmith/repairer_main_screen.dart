import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/repairer_profile_screen.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/locksmith_home_screen.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/repairer_chat_list_screen.dart';
import 'package:flutter_application_test/app/views/screens/locksmith/repairer_home_screen.dart';

class RepairerMainScreen extends StatefulWidget {
  const RepairerMainScreen({super.key});

  @override
  State<RepairerMainScreen> createState() => _RepairerMainScreenState();
}

class _RepairerMainScreenState extends State<RepairerMainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    RepairerHomeScreen(),
    LocksmithHomeScreen(),
    RepairerChatListScreen(),
    RepairerProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Công việc',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
