import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/auth/auth_notifier.dart';
import '../models/user_model.dart';
import 'ai_summary/ai_copilot_chat_dialog.dart';
import 'context_badges.dart';
import 'dialogs.dart';
import 'honda_wing_logo.dart';
import 'state_views.dart';

class NavItem {
  final String title;
  final String short;
  final IconData icon;
  final String route;
  final String section; // Work | Insight
  final String? tooltip;

  const NavItem({
    required this.title,
    required this.short,
    required this.icon,
    required this.route,
    required this.section,
    this.tooltip,
  });
}

class AdminSubItem {
  final String title;
  final String route;
  final IconData icon;
  final String group; // Catalog | Network | Access | Company
  final bool superAdminOnly;
  final String? tooltip;

  const AdminSubItem({
    required this.title,
    required this.route,
    required this.icon,
    required this.group,
    this.superAdminOnly = false,
    this.tooltip,
  });
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
  bool _isSidebarCollapsed = false;
  List<Map<String, dynamic>> _branches = [];
  int _overdueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadShellData();
  }

  Future<void> _loadShellData() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/branches');
      if (mounted) {
        setState(() {
          _branches = List<Map<String, dynamic>>.from(res.data);
        });
      }
      // Fetch overdue follow-up count for real notification badge
      final fuRes =
          await dio.get('/follow-ups', queryParameters: {'filter': 'overdue'});
      if (mounted && fuRes.data is List) {
        setState(() {
          _overdueCount = (fuRes.data as List).length;
        });
      }
    } catch (_) {}
  }

  static const List<AdminSubItem> adminSubItems = [
    AdminSubItem(
      title: 'Vehicle Masters',
      route: '/admin/vehicles',
      icon: AppIcons.vehicle,
      group: 'Catalog',
      tooltip: 'Manage Honda two-wheelers, variants, prices & brochures',
    ),
    AdminSubItem(
      title: 'Model Groups',
      route: '/admin/model-groups',
      icon: Icons.layers_outlined,
      group: 'Catalog',
      tooltip: 'Scooters, Commuters, Premium & BigWing categories',
    ),
    AdminSubItem(
      title: 'Colours',
      route: '/admin/colours',
      icon: Icons.palette_outlined,
      group: 'Catalog',
      tooltip: 'Palette shades, paint codes & vehicle swatches',
    ),
    AdminSubItem(
      title: 'Finance Providers',
      route: '/admin/financiers',
      icon: Icons.account_balance_outlined,
      group: 'Catalog',
      tooltip: 'Banking partners, interest rates & hypothecation fee',
    ),
    AdminSubItem(
      title: 'Areas',
      route: '/admin/areas',
      icon: AppIcons.branch,
      group: 'Network',
      tooltip: 'Delivery areas, pin codes & territorial boundaries',
    ),
    AdminSubItem(
      title: 'Lead Sources',
      route: '/admin/lead-sources',
      icon: Icons.campaign_outlined,
      group: 'Network',
      tooltip: 'Walk-ins, telephonic, BikeWale, ads & digital leads',
    ),
    AdminSubItem(
      title: 'Branches',
      route: '/admin/branches',
      icon: Icons.storefront_outlined,
      group: 'Network',
      tooltip: 'Yash Honda showroom network (BigWing & RedWing)',
    ),
    AdminSubItem(
      title: 'Users',
      route: '/admin/users',
      icon: Icons.people_outline,
      group: 'Access',
      superAdminOnly: true,
      tooltip: 'Staff logins, branch allocations & role-based permissions',
    ),
    AdminSubItem(
      title: 'Company Profile',
      route: '/admin/company-profile',
      icon: Icons.business_outlined,
      group: 'Company',
      superAdminOnly: true,
      tooltip: 'Letterhead, bank details, GSTIN & quotation branding',
    ),
  ];

  static const List<NavItem> navItems = [
    NavItem(
      title: 'Dashboard',
      short: 'Dashboard',
      icon: Icons.grid_view_rounded,
      route: '/dashboard',
      section: 'Work',
      tooltip: 'Floor Dashboard: Live showroom timeline & rep attendance',
    ),
    NavItem(
      title: 'Summary',
      short: 'Summary',
      icon: Icons.bar_chart_rounded,
      route: '/summary',
      section: 'Insight',
      tooltip: 'Dealership Summary: Branch comparison & executive overview',
    ),
    NavItem(
      title: 'Enquiries',
      short: 'Enquiries',
      icon: Icons.assignment_outlined,
      route: '/enquiries',
      section: 'Work',
      tooltip: 'Enquiries: Walk-in & phone leads, quotes & customer pipeline',
    ),
    NavItem(
      title: 'Follow-ups',
      short: 'Follow-ups',
      icon: Icons.calendar_today_outlined,
      route: '/follow-ups',
      section: 'Work',
      tooltip: 'Follow-ups: Scheduled callbacks, test rides & prospect history',
    ),
    NavItem(
      title: 'Reports',
      short: 'Reports',
      icon: Icons.insert_chart_outlined_rounded,
      route: '/reports',
      section: 'Insight',
      tooltip: 'Reports: Sales analytics, conversions & financial metrics',
    ),
  ];

  List<NavItem> _permittedNavItems(UserModel user) {
    return navItems.where((item) {
      if (item.route == '/dashboard' || item.route == '/summary') {
        return user.canAccessDashboard;
      }
      if (item.route == '/reports') {
        return user.canAccessReports;
      }
      return true; // Enquiries & Follow-ups available to all authenticated roles
    }).toList();
  }

  List<AdminSubItem> _permittedAdminItems(UserModel user) {
    if (!user.canAccessAdminPanel) return [];
    return adminSubItems.where((sub) {
      if (sub.superAdminOnly && !user.isSuperAdmin) return false;
      return true;
    }).toList();
  }

  String _selectedBranchName(String branchId) {
    if (branchId == 'all') return 'All branches';
    final match =
        _branches.where((b) => b['id'].toString() == branchId).firstOrNull;
    return match?['name']?.toString() ?? 'Selected branch';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: widget.body,
      );
    }

    final filteredItems = _permittedNavItems(user);

    return ResponsiveLayout(
      phone: _buildMobileLayout(context, ref, user, filteredItems),
      tablet: _buildDesktopLayout(context, ref, user, filteredItems,
          forceCompact: true),
      compactDesktop: _buildDesktopLayout(context, ref, user, filteredItems,
          forceCompact: true),
      desktop: _buildDesktopLayout(context, ref, user, filteredItems,
          forceCompact: false),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    List<NavItem> items, {
    required bool forceCompact,
  }) {
    final collapsed = forceCompact || _isSidebarCollapsed;
    final sidebarWidth = collapsed ? 68.0 : 208.0;
    final adminItems = _permittedAdminItems(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: sidebarWidth,
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Mark: Full Honda Logo (Wing + HONDA) alongside "Yash Honda" + consistent toggle
                Container(
                  height: 64,
                  padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message:
                              'Yash Honda Dealership CRM • Official Pune Network',
                          child: InkWell(
                            onTap: () => context.go(
                              user.canAccessDashboard
                                  ? '/dashboard'
                                  : '/enquiries',
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HondaWingLogo(
                                  width: collapsed ? 26 : 38,
                                  height: collapsed ? 18 : 22,
                                  showWordmark: !collapsed,
                                ),
                                if (!collapsed) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Yash Honda',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        Text(
                                          user.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!forceCompact)
                        Tooltip(
                          message: collapsed
                              ? 'Expand navigation'
                              : 'Collapse navigation',
                          child: InkWell(
                            onTap: () => setState(
                                () => _isSidebarCollapsed = !_isSidebarCollapsed),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Icon(
                                collapsed
                                    ? Icons.chevron_right_rounded
                                    : Icons.chevron_left_rounded,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Main Navigation Links
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      ...items
                          .map((item) => _buildSidebarNavTile(item, collapsed)),
                      const SizedBox(height: 10),
                      if (adminItems.isNotEmpty) ...[
                        if (!collapsed)
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
                          )
                        else
                          Tooltip(
                            message: 'Admin Panel',
                            child: IconButton(
                              icon: Icon(
                                Icons.settings_outlined,
                                color: widget.currentRoute.startsWith('/admin')
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                              onPressed: () =>
                                  context.go(adminItems.first.route),
                            ),
                          ),
                        if (!collapsed && _isAdminExpanded)
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Column(
                              children: adminItems.map((subItem) {
                                final isSubSelected =
                                    widget.currentRoute == subItem.route;
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
                                                overflow: TextOverflow.ellipsis,
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
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(0xFFDC2626),
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                user.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Tooltip(
                    message: 'Sign out of Yash Honda CRM securely',
                    child: InkWell(
                      onTap: () =>
                          ref.read(authStateProvider.notifier).logout(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 36,
                        padding: EdgeInsets.symmetric(
                            horizontal: collapsed ? 0 : 10),
                        child: Row(
                          mainAxisAlignment: collapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            const Icon(Icons.arrow_back_rounded,
                                size: 16, color: Color(0xFF64748B)),
                            if (!collapsed) ...[
                              const SizedBox(width: 8),
                              const Text(
                                'Sign out',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildTopHeaderBar(context, ref, user),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavTile(NavItem item, bool collapsed) {
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
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFEE2E2) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF64748B),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.short,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPageTitle(String route) {
    if (route.startsWith('/dashboard')) return 'Live floor';
    if (route.startsWith('/summary')) return 'Dealership summary';
    if (route.startsWith('/enquiries')) return 'Enquiries';
    if (route.startsWith('/follow-ups')) return 'Follow-ups';
    if (route.startsWith('/reports')) return 'Reports';
    if (route.startsWith('/admin')) return 'Administration';
    return 'Yash Honda';
  }

  Widget _buildTopHeaderBar(
      BuildContext context, WidgetRef ref, UserModel user) {
    final lastUpdated = ref.watch(lastDataUpdatedProvider);
    final hasError = ref.watch(dataFreshnessErrorProvider);
    final showFreshness = !widget.currentRoute.startsWith('/admin') &&
        (lastUpdated != null || hasError);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutterDesktop),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(_getPageTitle(widget.currentRoute),
                style: AppTypography.title),
          ),
          if (showFreshness) ...[
            const SizedBox(width: AppSpacing.s12),
            FreshnessBadge(
              lastUpdatedAt: lastUpdated,
              hasError: hasError,
              onRefresh: _loadShellData,
            ),
          ],
          const Spacer(),
          _buildBranchDropdown(ref, user),
          const SizedBox(width: AppSpacing.s8),
          IconButton(
            tooltip: 'AI Dealership Assistant',
            icon: const Icon(AppIcons.ai, color: AppColors.aiAccent),
            onPressed: () => _showAiInsightsDialog(context, ref),
          ),
          IconButton(
            tooltip: _overdueCount > 0
                ? 'Notifications ($_overdueCount overdue follow-ups)'
                : 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(AppIcons.notifications, color: AppColors.body),
                if (_overdueCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showNotificationsDialog(context),
          ),
          const SizedBox(width: AppSpacing.s8),
          ElevatedButton.icon(
            onPressed: () => context.go('/tablet'),
            icon: const Icon(AppIcons.add, size: 18),
            label: const Text('New enquiry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown(WidgetRef ref, UserModel user) {
    final activeBranchId = ref.watch(selectedBranchIdProvider);
    final isSuperAdmin = user.isSuperAdmin || user.isOwner;
    final userBranchIds = user.branches.map((b) => b.id).toSet();

    final visibleBranches = isSuperAdmin || userBranchIds.isEmpty
        ? _branches
        : _branches
            .where((b) => userBranchIds.contains(b['id'].toString()))
            .toList();

    String validValue;
    if (isSuperAdmin) {
      validValue =
          (visibleBranches.any((b) => b['id'].toString() == activeBranchId) ||
                  activeBranchId == 'all')
              ? activeBranchId
              : 'all';
    } else {
      if (visibleBranches.any((b) => b['id'].toString() == activeBranchId)) {
        validValue = activeBranchId;
      } else if (visibleBranches.isNotEmpty) {
        validValue = visibleBranches.first['id'].toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ref.read(selectedBranchIdProvider) != validValue) {
            ref.read(selectedBranchIdProvider.notifier).state = validValue;
          }
        });
      } else {
        validValue = 'all';
      }
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.secondary),
          style: AppTypography.label.copyWith(color: AppColors.ink),
          items: [
            if (isSuperAdmin)
              const DropdownMenuItem(value: 'all', child: Text('All branches')),
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
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    List<NavItem> permittedItems,
  ) {
    final activeBranchId = ref.watch(selectedBranchIdProvider);

    // Role-aware primary mobile tabs (max 3 + "More")
    final List<NavItem> primaryTabs = [];
    if (user.canAccessDashboard) {
      primaryTabs
          .add(permittedItems.firstWhere((i) => i.route == '/dashboard'));
    }
    primaryTabs.add(permittedItems.firstWhere((i) => i.route == '/enquiries'));
    primaryTabs.add(permittedItems.firstWhere((i) => i.route == '/follow-ups'));

    final destinations = [
      ...primaryTabs.map(
        (item) => NavigationDestination(
          icon: Icon(item.icon),
          label: item.short,
        ),
      ),
      const NavigationDestination(
        icon: Icon(AppIcons.more),
        label: 'More',
      ),
    ];

    int selectedIndex = primaryTabs
        .length; // Default to 'More' if route is Summary/Reports/Admin
    for (int i = 0; i < primaryTabs.length; i++) {
      if (widget.currentRoute == primaryTabs[i].route ||
          (primaryTabs[i].route != '/dashboard' &&
              widget.currentRoute.startsWith(primaryTabs[i].route))) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: AppSpacing.s16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getPageTitle(widget.currentRoute),
                style: AppTypography.section),
            Text(
              _selectedBranchName(activeBranchId),
              style: AppTypography.caption,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(AppIcons.notifications),
                if (_overdueCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showNotificationsDialog(context),
          ),
        ],
      ),
      body: widget.body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/tablet'),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(AppIcons.add),
        label: const Text('New enquiry'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (idx) {
          if (idx < primaryTabs.length) {
            context.go(primaryTabs[idx].route);
          } else {
            _showMobileMoreSheet(context, ref, user);
          }
        },
        destinations: destinations,
      ),
    );
  }

  void _showMobileMoreSheet(
      BuildContext context, WidgetRef ref, UserModel user) {
    final adminItems = _permittedAdminItems(user);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.brand,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: AppTypography.bodyStrong),
                        Text(user.displayName, style: AppTypography.caption),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              _buildBranchDropdown(ref, user),
              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1),
              if (user.canAccessDashboard)
                ListTile(
                  leading: const Icon(AppIcons.summary),
                  title: const Text('Dealership summary'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/summary');
                  },
                ),
              if (user.canAccessReports)
                ListTile(
                  leading: const Icon(AppIcons.reports),
                  title: const Text('Reports'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/reports');
                  },
                ),
              ListTile(
                leading: const Icon(AppIcons.ai, color: AppColors.aiAccent),
                title: const Text('AI Dealership Assistant'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAiInsightsDialog(context, ref);
                },
              ),
              if (adminItems.isNotEmpty) ...[
                const Divider(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('ADMINISTRATION', style: AppTypography.overline),
                ),
                ...adminItems.map(
                  (sub) => ListTile(
                    leading: Icon(sub.icon),
                    title: Text(sub.title),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.go(sub.route);
                    },
                  ),
                ),
              ],
              const Divider(height: 16),
              ListTile(
                leading: const Icon(AppIcons.logout, color: AppColors.danger),
                title: Text(
                  'Sign out',
                  style: AppTypography.bodyStrong
                      .copyWith(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(authStateProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _NotificationsDialog(
        onOpenFollowUps: () {
          Navigator.pop(ctx);
          context.go('/follow-ups');
        },
      ),
    );
  }

  void _showAiInsightsDialog(BuildContext context, WidgetRef ref) {
    final activeBranchId = ref.read(selectedBranchIdProvider);
    AiCopilotChatDialog.show(context, initialBranchId: activeBranchId);
  }
}

class _NotificationsDialog extends ConsumerStatefulWidget {
  final VoidCallback onOpenFollowUps;

  const _NotificationsDialog({required this.onOpenFollowUps});

  @override
  ConsumerState<_NotificationsDialog> createState() =>
      _NotificationsDialogState();
}

class _NotificationsDialogState extends ConsumerState<_NotificationsDialog> {
  bool _loading = true;
  String? _error;
  List<dynamic> _overdue = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.get('/follow-ups', queryParameters: {'filter': 'overdue'});
      if (mounted) {
        setState(() {
          _overdue = res.data is List ? res.data as List : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Could not load notifications. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogScaffold(
      title: 'Notifications',
      subtitle: 'Overdue follow-ups & pending callbacks',
      actions: [
        TextButton(
          onPressed: widget.onOpenFollowUps,
          child: const Text('Open Follow-ups'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: _loading
          ? const LoadingState(rows: 3)
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _overdue.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.notifications,
                      title: 'All caught up',
                      message:
                          'No overdue follow-ups require attention right now.',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _overdue.take(8).map((fu) {
                        final customer =
                            fu['enquiry']?['customer']?['name'] ?? 'Customer';
                        final remarks =
                            fu['remarks'] ?? 'Scheduled callback overdue';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(AppIcons.warning,
                              color: AppColors.danger),
                          title: Text(customer.toString(),
                              style: AppTypography.bodyStrong),
                          subtitle: Text(remarks.toString(),
                              style: AppTypography.caption),
                          onTap: widget.onOpenFollowUps,
                        );
                      }).toList(),
                    ),
    );
  }
}
