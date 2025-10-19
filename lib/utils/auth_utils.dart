String emailFromUsername(String username) {
  // ensure no stray spaces and convert to lowercase for consistency
  final u = username.trim().toLowerCase();
  return '$u@coldapp.com';
}
