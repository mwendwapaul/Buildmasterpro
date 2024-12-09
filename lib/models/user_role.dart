enum UserRole {
  admin(['view_reports', 'manage_users', 'edit_settings']),
  manager(['view_reports', 'assign_tasks']),
  employee(['view_tasks', 'submit_reports']),
  viewer(['view_reports']);

  final List<String> permissions;

  const UserRole(this.permissions);

  String get displayName => name[0].toUpperCase() + name.substring(1);
}
