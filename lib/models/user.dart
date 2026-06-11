import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final int id;
  final String email;
  @JsonKey(name: 'full_name')
  final String? fullName;
  final String role;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'last_login')
  final String? lastLogin;

  User({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return _$UserFromJson(json);
    } catch (e) {
      print('Error parsing User: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
  Map<String, dynamic> toJson() => _$UserToJson(this);
  
  bool get isContractor => role == 'contractor';
  bool get isClient => role == 'client';
  bool get isAdmin => role == 'admin';
}
