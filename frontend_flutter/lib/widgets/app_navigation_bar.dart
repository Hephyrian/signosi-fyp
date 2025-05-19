import 'package:flutter/material.dart';
import '../screens/debug_screen.dart';

class AppNavigationBar extends StatefulWidget implements PreferredSizeWidget {
  final String activeScreen;
  final Function(int)? onTapLogo;
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  const AppNavigationBar({
    super.key, 
    required this.activeScreen,
    this.onTapLogo,
    this.isDarkMode = false,
    this.onToggleTheme,
  });

  @override
  State<AppNavigationBar> createState() => _AppNavigationBarState();

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _AppNavigationBarState extends State<AppNavigationBar> {
  int _logoTapCount = 0;
  final int _requiredTapsForDebug = 5;

  void _handleLogoTap() {
    setState(() {
      _logoTapCount++;
    });
    
    if (widget.onTapLogo != null) {
      widget.onTapLogo!(_logoTapCount);
    }
    
    if (_logoTapCount >= _requiredTapsForDebug) {
      // Reset count and navigate to debug screen
      _logoTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DebugScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo only
              GestureDetector(
                onTap: _handleLogoTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/signosi_logo_hand.png',
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              // Actions
              Row(
                children: [
                  _buildNavAction(
                    icon: Icons.home_rounded,
                    isActive: widget.activeScreen == 'home',
                    tooltip: 'Home',
                    onPressed: () {
                      if (widget.activeScreen != 'home') {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildNavAction(
                    icon: Icons.account_circle_rounded,
                    isActive: widget.activeScreen == 'profile',
                    tooltip: 'Profile',
                    onPressed: () {
                      if (widget.activeScreen != 'profile') {
                        Navigator.pushNamed(context, '/profile');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildNavAction(
                    icon: widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    isActive: false,
                    tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    onPressed: widget.onToggleTheme ?? () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavAction({
    required IconData icon, 
    required bool isActive,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive 
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 24,
              color: isActive 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
} 