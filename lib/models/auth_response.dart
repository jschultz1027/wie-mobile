import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'auth_response.g.dart';

@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'token_type')
  final String? tokenType;
  final User user;

  AuthResponse({
    required this.accessToken,
    this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    try {
      return _$AuthResponseFromJson(json);
    } catch (e) {
      print('Error parsing AuthResponse: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}
