// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: (json['id'] as num).toInt(),
  email: json['email'] as String,
  fullName: json['full_name'] as String?,
  role: json['role'] as String,
  isActive: json['is_active'] as bool? ?? true,
  createdAt: json['created_at'] as String?,
  lastLogin: json['last_login'] as String?,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'full_name': instance.fullName,
  'role': instance.role,
  'is_active': instance.isActive,
  'created_at': instance.createdAt,
  'last_login': instance.lastLogin,
};
