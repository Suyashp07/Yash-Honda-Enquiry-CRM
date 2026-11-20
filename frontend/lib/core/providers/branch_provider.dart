import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global selected branch filter for Dashboard, Enquiries, and App Shell
/// 'all' means all branches in Pune
final selectedBranchIdProvider = StateProvider<String>((ref) => 'all');
