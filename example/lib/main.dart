class UserManager {
  final List<String> _users = [];

  void addUser(String name) {
    _users.add(name);
  }

  String? findUser(String name) {
    for (final user in _users) {
      if (user == name) return user;
    }
    return null;
  }
}
