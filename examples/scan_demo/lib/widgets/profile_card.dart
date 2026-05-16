class ProfileCard {
  String name;
  String email;
  int age;
  String bio;
  String avatarUrl;
  String location;
  String website;
  String company;
  String role;
  String department;
  String phone;
  String address;
  String city;
  String country;
  String postalCode;
  String timezone;
  String language;
  String theme;
  bool notificationsEnabled;
  bool emailVerified;
  bool twoFactorEnabled;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime lastLoginAt;
  List<String> tags;
  Map<String, dynamic> metadata;

  ProfileCard({
    required this.name,
    required this.email,
    required this.age,
    required this.bio,
    required this.avatarUrl,
    required this.location,
    required this.website,
    required this.company,
    required this.role,
    required this.department,
    required this.phone,
    required this.address,
    required this.city,
    required this.country,
    required this.postalCode,
    required this.timezone,
    required this.language,
    required this.theme,
    required this.notificationsEnabled,
    required this.emailVerified,
    required this.twoFactorEnabled,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
    required this.tags,
    required this.metadata,
  });

  String get displayName => '$name ($role, $department)';

  bool get isActive =>
      lastLoginAt.isAfter(DateTime.now().subtract(const Duration(days: 30)));
}
