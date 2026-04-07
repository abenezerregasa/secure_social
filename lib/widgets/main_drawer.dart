import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class MainDrawer extends StatelessWidget {
  final String userEmail;
  final VoidCallback onLogout;

  const MainDrawer({
    super.key,
    required this.userEmail,
    required this.onLogout,
  });

  String _getInitial(String email) {
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      // Setting width to a standard professional ratio
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Refined Header Section ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _getInitial(userEmail),
                      style: const TextStyle(
                        fontSize: 22, 
                        color: Colors.white, 
                        fontWeight: FontWeight.w800
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userEmail.split('@')[0], // Shows name part of email
                  style: const TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  userEmail,
                  style: const TextStyle(
                    color: AppColors.textMuted, 
                    fontSize: 14, 
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(thickness: 1),
          ),

          const SizedBox(height: 16),

          // --- Navigation Items ---
          _DrawerItem(
            icon: Icons.rss_feed_rounded,
            label: 'Home Feed',
            isActive: true, // Visual indicator for the current screen
            onTap: () => Navigator.pop(context),
          ),
          
          _DrawerItem(
            icon: Icons.person_outline_rounded,
            label: 'My Profile',
            onTap: () {
              Navigator.pop(context);
              // Future profile logic here
            },
          ),

          _DrawerItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.pop(context);
              // Future settings logic here
            },
          ),

          const Spacer(), // Pushes logout to the bottom

          // --- Bottom Logout Section ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.error, 
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// Internal Helper for consistent menu items
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isActive ? AppColors.accent.withOpacity(0.08) : Colors.transparent,
        leading: Icon(
          icon, 
          color: isActive ? AppColors.accent : AppColors.textMuted,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.accent : AppColors.textMain,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}