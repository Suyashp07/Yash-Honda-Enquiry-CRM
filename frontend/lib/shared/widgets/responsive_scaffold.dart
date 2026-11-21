import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/networking/api_client.dart';
import '../../features/auth/auth_notifier.dart';
import '../models/user_model.dart';
import 'ai_summary/ai_summary_card.dart';

class NavItem {
  final String title;
  final String short;
  final IconData icon;
  final String route;
  final bool superAdminOnly;
  final bool hideFromSalesExec;
  final String? tooltip;

  const NavItem({
    required this.title,
    required this.short,
    required this.icon,
    required this.route,
    this.superAdminOnly = false,
    this.hideFromSalesExec = false,
    this.tooltip,
  });
}

class AdminSubItem {
  final String title;
  final String route;
  final IconData icon;
  final String? tooltip;

  const AdminSubItem(
      {required this.title,
      required this.route,
      required this.icon,
      this.tooltip});
}

class ResponsiveScaffold extends ConsumerStatefulWidget {
  final Widget body;
  final String currentRoute;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    required this.currentRoute,
  });

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  bool _isAdminExpanded = true;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/branches');
      if (mounted) {
        setState(() {
          _branches = List<Map<String, dynamic>>.from(res.data);
        });
      }
    } catch (_) {}
  }

  static const List<AdminSubItem> adminSubItems = [
    AdminSubItem(
        title: 'Vehicle Masters',
        route: '/admin/vehicles',
        icon: Icons.two_wheeler_outlined,
        tooltip: 'Manage Honda two-wheelers, variants, prices & brochures'),
    AdminSubItem(
        title: 'Model Groups',
        route: '/admin/model-groups',
        icon: Icons.layers_outlined,
        tooltip: 'Scooters, Commuters, Premium & BigWing categories'),
    AdminSubItem(
        title: 'Colours',
        route: '/admin/colours',
        icon: Icons.palette_outlined,
        tooltip: 'Palette shades, paint codes & vehicle swatches'),
    AdminSubItem(
        title: 'Add-ons',
        route: '/admin/accessories',
        icon: Icons.inventory_2_outlined,
        tooltip: 'Accessories, AMC, extended warranties & helmet kits'),
    AdminSubItem(
        title: 'Finance Providers',
        route: '/admin/financiers',
        icon: Icons.account_balance_outlined,
        tooltip: 'Banking partners, interest rates & hypothecation fee'),
    AdminSubItem(
        title: 'Areas',
        route: '/admin/areas',
        icon: Icons.location_on_outlined,
        tooltip: 'Pune delivery areas, pin codes & territorial boundaries'),
    AdminSubItem(
        title: 'Lead Sources',
        route: '/admin/lead-sources',
        icon: Icons.campaign_outlined,
        tooltip: 'Walk-ins, telephonic, BikeWale, ads & digital leads'),
    AdminSubItem(
        title: 'Branches',
        route: '/admin/branches',
        icon: Icons.storefront_outlined,
        tooltip: 'Yash Honda showroom network (BigWing & RedWing)'),
    AdminSubItem(
        title: 'Users',
        route: '/admin/users',
        icon: Icons.people_outline,
        tooltip: 'Staff logins, branch allocations & role-based permissions'),
    AdminSubItem(
        title: 'Company Profile',
        route: '/admin/company-profile',
        icon: Icons.business_outlined,
        tooltip: 'Letterhead, bank details, GSTIN & quotation branding'),
  ];

  static const List<NavItem> navItems = [
    NavItem(
      title: 'Dashboard',
      short: 'Dashboard',
      icon: Icons.grid_view_rounded,
      route: '/dashboard',
      hideFromSalesExec: true,
      tooltip: 'Floor Dashboard: Live showroom timeline & rep attendance',
    ),
    NavItem(
      title: 'Summary',
      short: 'Summary',
      icon: Icons.bar_chart_rounded,
      route: '/summary',
      hideFromSalesExec: true,
      tooltip:
          'Dealership Summary: Location-wise As-On-Date & MTD Leads, Bookings & Conversion',
    ),
    NavItem(
      title: 'Enquiries',
      short: 'Enquiries',
      icon: Icons.receipt_long_outlined,
      route: '/enquiries',
      tooltip: 'Enquiries: Walk-in & phone leads, quotes & customer pipeline',
    ),
    NavItem(
      title: 'Follow-ups',
      short: 'Follow-ups',
      icon: Icons.group_outlined,
      route: '/follow-ups',
      tooltip: 'Follow-ups: Scheduled callbacks, test rides & prospect history',
    ),
    NavItem(
      title: 'Reports',
      short: 'Reports',
      icon: Icons.insert_chart_outlined_rounded,
      route: '/reports',
      hideFromSalesExec: true,
      tooltip: 'Reports: Sales analytics, conversions & financial metrics',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: widget.body,
      );
    }

    final filteredItems = navItems.where((item) {
      if (item.superAdminOnly && !user.isSuperAdmin) return false;
      if (item.route == '/reports' && !user.canAccessReports) return false;
      if (item.hideFromSalesExec && user.isSalesExec) return false;
      return true;
    }).toList();

    return ResponsiveLayout(
      phone: _buildMobileLayout(context, ref, filteredItems),
      tablet: _buildDesktopLayout(context, ref, filteredItems),
      desktop: _buildDesktopLayout(context, ref, filteredItems),
    );
  }

  Widget _buildDesktopLayout(
      BuildContext context, WidgetRef ref, List<NavItem> items) {
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: Row(
        children: [
          // Expanded 230px Navigation Sidebar matching Prototype Screenshots
          Container(
            width: 230,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Mark: Red H box + "Yash Honda" + Role subtitle matching prototype
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Tooltip(
                    message:
                        'Yash Honda Dealership CRM • Official Pune Network',
                    child: InkWell(
                      onTap: () => context.go(user?.canAccessDashboard == true
                          ? '/dashboard'
                          : '/enquiries'),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'H',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yash Honda',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                user?.displayName ?? 'Super Admin',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Main Navigation Links
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      ...items.map((item) {
                        final isSelected = widget.currentRoute == item.route ||
                            (item.route != '/dashboard' &&
                                widget.currentRoute.startsWith(item.route));

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Tooltip(
                            message: item.tooltip ?? item.short,
                            child: InkWell(
                              onTap: () => context.go(item.route),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 38,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFEE2E2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 18,
                                      color: isSelected
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      item.short,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 10),

                      // Collapsible Admin Panel Accordion (Super Admin & Branch Manager ONLY)
                      if (user?.canAccessAdminPanel == true) ...[
                        Tooltip(
                          message: _isAdminExpanded
                              ? 'Click to collapse Admin Panel configuration sub-menus'
                              : 'Click to expand Admin Panel master records & configurations',
                          child: InkWell(
                            onTap: () => setState(
                                () => _isAdminExpanded = !_isAdminExpanded),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 38,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.settings_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Admin Panel',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _isAdminExpanded
                                        ? Icons.arrow_drop_up_rounded
                                        : Icons.arrow_drop_down_rounded,
                                    size: 20,
                                    color: const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_isAdminExpanded) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Column(
                              children: adminSubItems.where((subItem) {
                                if (user?.isBranchManager == true &&
                                    (subItem.route == '/admin/users' ||
                                        subItem.route ==
                                            '/admin/company-profile')) {
                                  return false;
                                }
                                return true;
                              }).map((subItem) {
                                final isSubSelected = widget.currentRoute ==
                                        subItem.route ||
                                    (widget.currentRoute.startsWith('/admin') &&
                                        widget.currentRoute == subItem.route);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Tooltip(
                                    message: subItem.tooltip ?? subItem.title,
                                    child: InkWell(
                                      onTap: () => context.go(subItem.route),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        height: 34,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: isSubSelected
                                              ? const Color(0xFFFFF1F2)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: isSubSelected
                                              ? const Border(
                                                  left: BorderSide(
                                                      color: Color(0xFFDC2626),
                                                      width: 3),
                                                )
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              subItem.icon,
                                              size: 15,
                                              color: isSubSelected
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                subItem.title,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: isSubSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isSubSelected
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Bottom Exit / Sign Out Button
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Tooltip(
                    message: 'Sign out of Yash Honda CRM securely',
                    child: InkWell(
                      onTap: () =>
                          ref.read(authStateProvider.notifier).logout(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back_rounded,
                                size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text(
                              'Sign out',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Screen Area with Top Header Bar + Content
          Expanded(
            child: Column(
              children: [
                // Top Header Bar matching Prototype
                _buildTopHeaderBar(context, ref, user),

                // Main Page Content
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle(String route) {
    if (route.startsWith('/dashboard')) return 'Live floor';
    if (route.startsWith('/summary')) return 'Dealership Summary';
    if (route.startsWith('/enquiries')) return 'Enquiries';
    if (route.startsWith('/follow-ups')) return 'Follow-ups';
    if (route.startsWith('/reports')) return 'Reports';
    if (route.startsWith('/admin')) return 'Admin Panel';
    return 'Yash Honda';
  }

  Widget _buildTopHeaderBar(
      BuildContext context, WidgetRef ref, UserModel? user) {
    final isDashboard = widget.currentRoute == '/dashboard';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9F6),
      ),
      child: Row(
        children: [
          // Left: Page Title directly opposite right action buttons
          if (isDashboard)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Live floor',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Updated just now',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            )
          else
            Text(
              _getPageTitle(widget.currentRoute),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),

          const Spacer(),

          // Right side controls matching prototype:
          // [All branches (Pune) v] [Robot] [Bell with red dot] [+ New enquiry [N]]

          // 1. Branch Selector Dropdown
          Consumer(
            builder: (context, ref, child) {
              final activeBranchId = ref.watch(selectedBranchIdProvider);
              final isSuperAdmin =
                  user?.isSuperAdmin == true || user?.isOwner == true;
              final userBranchIds =
                  user?.branches.map((b) => b.id).toSet() ?? {};

              final visibleBranches = isSuperAdmin || userBranchIds.isEmpty
                  ? _branches
                  : _branches
                      .where((b) => userBranchIds.contains(b['id'].toString()))
                      .toList();

              String validValue;
              if (isSuperAdmin) {
                validValue = (visibleBranches
                            .any((b) => b['id'].toString() == activeBranchId) ||
                        activeBranchId == 'all')
                    ? activeBranchId
                    : 'all';
              } else {
                if (visibleBranches
                    .any((b) => b['id'].toString() == activeBranchId)) {
                  validValue = activeBranchId;
                } else if (visibleBranches.isNotEmpty) {
                  validValue = visibleBranches.first['id'].toString();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (ref.read(selectedBranchIdProvider) != validValue) {
                      ref.read(selectedBranchIdProvider.notifier).state =
                          validValue;
                    }
                  });
                } else {
                  validValue = 'all';
                }
              }

              return Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: validValue,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                    items: [
                      if (isSuperAdmin)
                        const DropdownMenuItem(
                            value: 'all', child: Text('All branches (Pune)')),
                      ...visibleBranches.map((b) {
                        final wing = b['wing'] ??
                            (b['name'].toString().contains('BigWing') ||
                                    b['code'].toString().startsWith('BW')
                                ? 'BigWing'
                                : 'RedWing');
                        final name = b['name']?.toString() ?? 'Branch';
                        return DropdownMenuItem(
                          value: b['id'].toString(),
                          child: Text('$name ($wing)'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedBranchIdProvider.notifier).state = val;
                      }
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // 2. Robot / AI Insights Icon Button (in soft rounded white container)
          Tooltip(
            message:
                'AI Dealership Executive Insights - Real-time analysis powered by Gemini AI',
            child: InkWell(
              onTap: () => _showAiInsightsDialog(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    size: 18, color: Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Notification Bell with red dot
          Tooltip(
            message: 'Urgent follow-ups & notifications',
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      size: 18, color: Color(0xFF64748B)),
                  Positioned(
                    top: 8,
                    right: 9,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 4. "+ New enquiry [N]" Red Button matching prototype
          Tooltip(
            message:
                'Create a new customer walk-in or telephonic enquiry (Shortcut: N)',
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => context.go('/tablet'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 16),
                  const SizedBox(width: 4),
                  const Text('New enquiry',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB91C1C),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('N',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 5. Profile Avatar (matching prototype green circle 'S')
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF10B981),
            child: Text(
              user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
      BuildContext context, WidgetRef ref, List<NavItem> items) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        titleSpacing: 16,
        leadingWidth: 46,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0000),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text('YH',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ),
          ),
        ),
        title: const Text('Yash Honda',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFFCC0000))),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFFCC0000)),
            tooltip: 'New Enquiry',
            onPressed: () => context.go('/tablet'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: widget.body,
      bottomNavigationBar: items.length >= 2
          ? BottomNavigationBar(
              currentIndex: _getBottomNavIndex(items),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFFCC0000),
              unselectedItemColor: const Color(0xFF64748B),
              selectedFontSize: 11,
              unselectedFontSize: 10,
              backgroundColor: Colors.white,
              onTap: (index) {
                if (index < items.length) {
                  context.go(items[index].route);
                }
              },
              items: items.take(5).map((item) {
                return BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.short,
                );
              }).toList(),
            )
          : null,
    );
  }

  int _getBottomNavIndex(List<NavItem> items) {
    for (int i = 0; i < items.length && i < 5; i++) {
      if (widget.currentRoute == items[i].route ||
          (items[i].route != '/dashboard' &&
              widget.currentRoute.startsWith(items[i].route))) {
        return i;
      }
    }
    return 0;
  }

  void _showAiInsightsDialog(BuildContext context, WidgetRef ref) {
    final activeBranchId = ref.read(selectedBranchIdProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Dealership Executive Briefing',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Real-time automated floor & enquiry intelligence',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiSummaryCard(
                branchCode: activeBranchId,
                range: 'today',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.key_outlined,
                        size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gemini API key can be configured in Admin Settings for automated predictive intelligence.',
                        style:
                            TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
