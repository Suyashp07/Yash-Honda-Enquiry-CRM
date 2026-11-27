import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global selected branch filter for Dashboard, Summary, Enquiries, Reports, and App Shell.
/// 'all' means all authorized branches.
final selectedBranchIdProvider = StateProvider<String>((ref) => 'all');

/// Tracks the timestamp of the most recent successful data refresh in the active view.
final lastDataUpdatedProvider = StateProvider<DateTime?>((ref) => null);

/// Tracks whether the active view's latest refresh failed.
final dataFreshnessErrorProvider = StateProvider<bool>((ref) => false);

/// Incremented whenever branches are created, edited, toggled, or deleted in Admin Panel.
final branchesRefreshProvider = StateProvider<int>((ref) => 0);
