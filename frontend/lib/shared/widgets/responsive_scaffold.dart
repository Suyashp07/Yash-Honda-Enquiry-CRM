import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../features/auth/auth_notifier.dart';

class NavItem {
  final String title;
  final IconData icon;
  final String route;
  final bool superAdminOnly;
  final bool hideFromSalesExec;

  const NavItem({
    required this.title,
    required this.icon,
    required this.route,
    this.superAdminOnly = false,
    this.hideFromSalesExec = false,
  });
}

class ResponsiveScaffold extends ConsumerWidget {
  final Widget body;
  final String currentRoute;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    required this.currentRoute,
  });

  static const List<NavItem> navItems = [
    NavItem(
      title: 'Floor Dashboard',
      icon: Icons.speed_outlined,
      route: '/dashboard',
      hideFromSalesExec: true,
    ),
    NavItem(
      title: 'Vehicle POS (Enquiry)',
      icon: Icons.two_wheeler_outlined,
      route: '/enquiries/vehicle-picker',
    ),
    NavItem(
      title: 'Enquiries List',
      icon: Icons.list_alt_outlined,
      route: '/enquiries',
    ),
    NavItem(
      title: 'Follow-ups',
      icon: Icons.event_note_outlined,
      route: '/follow-ups',
    ),
    NavItem(
      title: 'Dealership Summary',
      icon: Icons.analytics_outlined,
      route: '/summary',
      hideFromSalesExec: true,
    ),
    NavItem(
      title: 'Reports',
      icon: Icons.bar_chart_outlined,
      route: '/reports',
      hideFromSalesExec: true,
    ),
    NavItem(
      title: 'Masters Catalog',
      icon: Icons.inventory_2_outlined,
      route: '/masters',
      superAdminOnly: true,
    ),
    NavItem(
      title: 'Settings',
      icon: Icons.settings_outlined,
      route: '/settings',
      superAdminOnly: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    final filteredItems = navItems.where((item) {
      if (user == null) return false;
      if (item.superAdminOnly && !user.isSuperAdmin) return false;
      if (item.hideFromSalesExec && user.isSalesExec) return false;
      return true;
    }).toList();

    return ResponsiveLayout(
      phone: _buildMobileLayout(context, ref, filteredItems),
      tablet: _buildTabletLayout(context, ref, filteredItems),
      desktop: _buildDesktopLayout(context, ref, filteredItems),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref, List<NavItem> items) {
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      body: Row(
        children: [
          // Persistent Sidebar
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A), // Dark slate sidebar
              border: Border(right: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              children: [
                // Top Brand Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'H',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YASH HONDA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Pune Dealership CRM',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 1),

                // Navigation Items List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    children: items.map((item) {
                      final isSelected = currentRoute == item.route || currentRoute.startsWith('${item.route}/');
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          tileColor: isSelected ? AppColors.primary : Colors.transparent,
                          leading: Icon(
                            item.icon,
                            size: 19,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          onTap: () => context.go(item.route),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Bottom User Profile & Logout
                const Divider(color: Color(0xFF1E293B), height: 1),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Staff User',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              user?.role.replaceAll('_', ' ') ?? '',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 17, color: Color(0xFF94A3B8)),
                        onPressed: () => ref.read(authStateProvider.notifier).logout(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main View Body
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, WidgetRef ref, List<NavItem> items) {
    return _buildDesktopLayout(context, ref, items);
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref, List<NavItem> items) {
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yash Honda CRM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F172A)),
              accountName: Text(user?.name ?? 'Staff'),
              accountEmail: Text('${user?.role.replaceAll('_', ' ')} • ${user?.mobile ?? ''}'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: items.map((item) {
                  final isSelected = currentRoute == item.route;
                  return ListTile(
                    leading: Icon(item.icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                    title: Text(item.title, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go(item.route);
                    },
                  );
                }).toList(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.statusClosed),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.statusClosed)),
              onTap: () => ref.read(authStateProvider.notifier).logout(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: body,
    );
  }
}
