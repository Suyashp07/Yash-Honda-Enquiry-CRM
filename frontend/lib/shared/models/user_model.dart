class BranchSummary {
  final String id;
  final String code;
  final String name;

  BranchSummary({required this.id, required this.code, required this.name});

  factory BranchSummary.fromJson(Map<String, dynamic> json) {
    return BranchSummary(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
  };
}

class UserModel {
  final String id;
  final String name;
  final String mobile;
  final String role; // SUPER_ADMIN | BRANCH_MANAGER | SALES_EXEC | ACCOUNTS | TELE_CALLER
  final List<BranchSummary> branches;

  UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.branches,
  });

  String get normalizedRole =>
      role.trim().toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');

  bool get isSuperAdmin =>
      normalizedRole == 'SUPER_ADMIN' ||
      normalizedRole == 'OWNER' ||
      role.toLowerCase().contains('super admin') ||
      role.toLowerCase().contains('owner');

  bool get isBranchManager =>
      normalizedRole == 'BRANCH_MANAGER' ||
      role.toLowerCase().contains('branch manager');

  bool get isSalesExec =>
      normalizedRole == 'SALES_EXEC' ||
      normalizedRole == 'SALES' ||
      normalizedRole == 'SALES_EXECUTIVE' ||
      role.toLowerCase().contains('sales');

  bool get isAccounts =>
      normalizedRole == 'ACCOUNTS' ||
      role.toLowerCase().contains('account');

  bool get isTeleCaller =>
      normalizedRole == 'TELE_CALLER' ||
      normalizedRole == 'TELECALLER' ||
      role.toLowerCase().contains('tele');

  bool get canAccessAdminPanel => isSuperAdmin || isBranchManager;
  bool get canAccessUsersMaster => isSuperAdmin;
  bool get canAccessCompanyProfile => isSuperAdmin;
  bool get canAccessReports => isSuperAdmin || isBranchManager || isAccounts;

  String get roleDisplayName {
    if (isSuperAdmin) return 'Super Admin';
    if (isBranchManager) return 'Branch Manager';
    if (isSalesExec) return 'Sales Executive';
    if (isAccounts) return 'Accounts';
    if (isTeleCaller) return 'Tele-caller';
    return role.replaceAll('_', ' ');
  }

  String get branchDisplayName {
    if (branches.isEmpty) return 'Pune';
    return branches.map((b) => b.name).join(', ');
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    var rawBranches = json['branches'] as List? ?? [];
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      role: json['role'] ?? 'SALES_EXEC',
      branches: rawBranches.map((b) => BranchSummary.fromJson(b)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'role': role,
    'branches': branches.map((b) => b.toJson()).toList(),
  };
}

