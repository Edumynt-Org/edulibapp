class AppUser {
  final String id;
  final String role;
  final bool isAnonymous;
  final String? email;
  final String? displayName;

  const AppUser({
    required this.id,
    required this.role,
    required this.isAnonymous,
    this.email,
    this.displayName,
  });
}
