import 'package:json_annotation/json_annotation.dart';

part 'verifier.g.dart';

@JsonSerializable()
class Verifier {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Verifier({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory Verifier.fromJson(Map<String, dynamic> json) => _$VerifierFromJson(json);
  Map<String, dynamic> toJson() => _$VerifierToJson(this);
}
