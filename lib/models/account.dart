class Account {
  final String id;
  final String username;
  final bool isRoot;

  Account({required this.id, required this.username, required this.isRoot});

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        username: json['username'] as String,
        isRoot: json['isRoot'] as bool? ?? false,
      );
}
