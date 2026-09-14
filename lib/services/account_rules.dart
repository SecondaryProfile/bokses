/// Shared validation for usernames and passwords, used by both the
/// setup/sign-in/sign-up form and the root account-management screen.
class AccountRules {
  AccountRules._();

  static const minUsernameLength = 3;
  static const minPasswordLength = 8;

  static String? validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a username';
    if (v.length < minUsernameLength) {
      return 'At least $minUsernameLength characters';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter a password';
    if (v.length < minPasswordLength) {
      return 'At least $minPasswordLength characters';
    }
    return null;
  }
}
