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
  final String role; // SUPER_ADMIN | BRANCH_MANAGER | SALES_EXEC
  final List<BranchSummary> branches;

  UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.branches,
  });

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isBranchManager => role == 'BRANCH_MANAGER';
  bool get isSalesExec => role == 'SALES_EXEC';

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

