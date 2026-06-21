import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import '../theme.dart';

/// الحاوية الرئيسية للتطبيق: تبدّل بين "الرئيسية" و"المفضلة" عبر شريط تنقل
/// سفلي ثابت، مع الحفاظ على حالة كل تبويب (IndexedStack) بدل إعادة بنائه
/// في كل مرة. هذا الشريط يظهر فقط هنا؛ أي شاشة تُفتح بـ Navigator.push من
/// داخل أحد التبويبين (تفاصيل عمل، بحث، قارئ) تغطي الشاشة بالكامل بدونه.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentTab = 0;

  static const List<Widget> _tabs = [
    HomeScreen(),
    FavoritesScreen(),
  ];

  void _onTabSelected(int index) {
    if (index == _currentTab) return;
    setState(() => _currentTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'الرئيسية',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.favorite_border,
                activeIcon: Icons.favorite,
                label: 'المفضلة',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool selected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  color: selected ? AppTheme.primaryRed : AppTheme.textMuted,
                  size: 26,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppTheme.primaryRed : AppTheme.textMuted,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
