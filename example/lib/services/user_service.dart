import '../widgets/profile_card.dart';

class UserService {
  final List<ProfileCard> _cache = [];

  Future<ProfileCard?> fetchUser(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _cache.firstWhere(
      (u) => u.displayName.contains(id),
      orElse: () => _cache.first,
    );
  }

  Future<void> syncUsers() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      _cache.add(_createMockUser(i));
    }
  }

  ProfileCard _createMockUser(int index) {
    return ProfileCard(
      name: 'User $index',
      email: 'user$index@example.com',
      age: 20 + index,
      bio: 'Bio for user $index',
      avatarUrl: 'https://example.com/avatars/$index.png',
      location: 'Location $index',
      website: 'https://user$index.example.com',
      company: 'Company $index',
      role: 'Role $index',
      department: 'Department $index',
      phone: '555-${index.toString().padLeft(4, '0')}',
      address: '${100 + index} Main St',
      city: 'City $index',
      country: 'Country $index',
      postalCode: '${10000 + index}',
      timezone: 'UTC${index > 5 ? "+$index" : "-$index"}',
      language: 'en',
      theme: 'light',
      notificationsEnabled: true,
      emailVerified: index > 0,
      twoFactorEnabled: index > 5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      tags: ['tag$index'],
      metadata: {'index': index, 'source': 'mock'},
    );
  }
}
