import 'package:ecommerece_app/features/auth/signup/data/models/user_entity.dart';

class MyUser {
  String userId;

  String email;

  String name;

  String url;
  List<String>? blocked = [];
  bool isSub;
  String? defaultAddressId;
  String? payerId;
  MyUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.url,
    this.payerId,
    this.isSub = false,
    this.defaultAddressId,
    this.blocked,
  });

  static final empty = MyUser(
    userId: '',
    email: '',
    name: '',
    url: '',
    blocked: [],
    defaultAddressId: '',
    isSub: false,
    payerId: '',
  );

  MyUserEntity toEntity() {
    return MyUserEntity(
      userId: userId,
      email: email,
      name: name,
      url: url,
      isSub: isSub,
      defaultAddressId: defaultAddressId,
      blocked: blocked,
      payerId: payerId ?? '',
    );
  }

  static MyUser fromEntity(MyUserEntity entity) {
    return MyUser(
      userId: entity.userId,
      email: entity.email,
      name: entity.name,
      url: entity.url,
      isSub: entity.isSub,
      defaultAddressId: entity.defaultAddressId,
      blocked: entity.blocked,
      payerId: entity.payerId,
    );
  }

  @override
  String toString() {
    return 'MyUser:$userId,$email,$name,$url';
  }
}
