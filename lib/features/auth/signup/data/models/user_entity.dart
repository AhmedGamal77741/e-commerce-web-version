class MyUserEntity {
  String userId;

  String email;

  String name;
  String? payerId;
  String url;
  List<String>? blocked = [];
  bool isSub;
  String? defaultAddressId;
  MyUserEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.url,
    this.blocked,
    this.isSub = false,
    this.defaultAddressId,
    this.payerId,
  });

  Map<String, Object?> toDocument() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'url': url,
      'blocked': blocked,
      'isSub': isSub,
      'defaultAddressId': defaultAddressId ?? '',
      'payerId': payerId,
    };
  }

  static MyUserEntity fromDocument(Map<String, dynamic> doc) {
    return MyUserEntity(
      userId: doc['userId'],
      email: doc['email'],
      name: doc['name'],
      url: doc['url'],
      blocked:
          (doc['blocked'] as List<dynamic>?)?.map((e) => e as String).toList(),
      isSub: doc['isSub'],
      defaultAddressId: doc['defaultAddressId'],
      payerId: doc['payerId'],
    );
  }
}
