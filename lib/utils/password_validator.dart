/// Password validation utility with modern security rules
class PasswordValidator {
  /// Minimum password length
  static const int minLength = 8;

  /// Validates password against modern security rules
  /// Returns null if valid, otherwise returns error message
  static String? validate(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }

    // Check for uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter (A-Z)';
    }

    // Check for lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter (a-z)';
    }

    // Check for digit
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number (0-9)';
    }

    // Check for special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character (!@#\$%^&*...)';
    }

    return null; // Valid password
  }

  /// Calculates password strength (0-4)
  /// 0 = Very Weak, 1 = Weak, 2 = Fair, 3 = Good, 4 = Strong
  static int getStrength(String password) {
    if (password.isEmpty) return 0;

    int strength = 0;

    // Length check
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;

    // Character variety checks
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    // Cap at 4
    return strength.clamp(0, 4);
  }

  /// Gets strength label
  static String getStrengthLabel(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Very Weak';
      case 2:
        return 'Weak';
      case 3:
        return 'Fair';
      case 4:
        return 'Strong';
      default:
        return 'Unknown';
    }
  }

  /// Gets password requirements as a list
  static List<PasswordRequirement> getRequirements(String password) {
    return [
      PasswordRequirement(
        label: 'At least 8 characters',
        isMet: password.length >= minLength,
      ),
      PasswordRequirement(
        label: 'One uppercase letter (A-Z)',
        isMet: password.contains(RegExp(r'[A-Z]')),
      ),
      PasswordRequirement(
        label: 'One lowercase letter (a-z)',
        isMet: password.contains(RegExp(r'[a-z]')),
      ),
      PasswordRequirement(
        label: 'One number (0-9)',
        isMet: password.contains(RegExp(r'[0-9]')),
      ),
      PasswordRequirement(
        label: 'One special character (!@#\$...)',
        isMet: password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
      ),
    ];
  }
}

/// Represents a single password requirement
class PasswordRequirement {
  final String label;
  final bool isMet;

  PasswordRequirement({required this.label, required this.isMet});
}
