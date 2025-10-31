import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/views/screens/customer/customer_chat_list_screen.dart';
import 'package:flutter_application_test/app/views/screens/customer/customer_map_screen.dart';
import 'package:flutter_application_test/app/views/screens/customer/home_screen.dart';
import 'package:flutter_application_test/app/views/screens/customer/profile_screen.dart';

class TabNavigator extends StatelessWidget {
  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.rootPage,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  @override
  Widget build(BuildContext context) {
    // Sửa đổi để sử dụng `pages` API, cho phép cập nhật widget gốc
    return Navigator(
      key: navigatorKey,
      pages: [MaterialPage(child: rootPage)],
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }
        return true;
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _serviceCategoryForMap;
  String? _categoryNameForMap;

  final _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
  };

  void _selectMapTabWithFilter(String category, String name) {
    setState(() {
      _selectedIndex = 1;
      _serviceCategoryForMap = category;
      _categoryNameForMap = name;
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      _navigatorKeys[index]?.currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
        // Reset bộ lọc bản đồ khi chuyển tab
        _serviceCategoryForMap = null;
        _categoryNameForMap = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          TabNavigator(
            navigatorKey: _navigatorKeys[0]!,
            rootPage: HomeScreen(onCategorySelected: _selectMapTabWithFilter),
          ),
          TabNavigator(
            navigatorKey: _navigatorKeys[1]!,
            rootPage: CustomerMapScreen(
              serviceCategory: _serviceCategoryForMap,
              categoryName: _categoryNameForMap,
            ),
          ),
          TabNavigator(
            navigatorKey: _navigatorKeys[2]!,
            rootPage: const CustomerChatListScreen(),
          ),
          TabNavigator(
            navigatorKey: _navigatorKeys[3]!,
            rootPage: const ProfileScreen(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Bản đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
