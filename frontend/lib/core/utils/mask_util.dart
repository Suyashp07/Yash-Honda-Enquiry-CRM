class MaskUtil {
  /// Masks mobile numbers (e.g. "6264984285" -> "••••••4285")
  static String maskMobile(String? mobile) {
    if (mobile == null || mobile.trim().isEmpty || mobile.trim() == '-') {
      return '-';
    }
    final clean = mobile.trim();
    if (clean.length < 5) return '••••••';
    if (clean.length >= 10) {
      return '••••••${clean.substring(clean.length - 4)}';
    }
    return '••••${clean.substring(clean.length - 2)}';
  }

  /// Masks emails (e.g. "pandeysuyash100@gmail.com" -> "p••••••@gmail.com")
  static String maskEmail(String? email) {
    if (email == null || email.trim().isEmpty || email.trim() == '-') {
      return '-';
    }
    final clean = email.trim();
    final parts = clean.split('@');
    if (parts.length == 2) {
      final name = parts[0];
      final domain = parts[1];
      if (name.length <= 2) {
        return '••@$domain';
      }
      return '${name[0]}••••••@$domain';
    }
    if (clean.length <= 4) return '••••';
    return '${clean.substring(0, 2)}••••••';
  }
}
