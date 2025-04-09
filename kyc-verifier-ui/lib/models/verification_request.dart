import 'package:json_annotation/json_annotation.dart';

part 'verification_request.g.dart';

enum KYCStatus {
  PENDING,
  VERIFIED,
  REJECTED,
  EXPIRED
}

enum DocumentType {
  ID_CARD,
  PASSPORT,
  DRIVERS_LICENSE,
  UTILITY_BILL,
  BANK_STATEMENT,
  SELFIE,
  OTHER
}

@JsonSerializable()
class VerificationRequest {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final DateTime dateOfBirth;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String? additionalInfo;
  final KYCStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;
  final String? verifierId;

  VerificationRequest({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.dateOfBirth,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    this.additionalInfo,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
    this.verifiedAt,
    this.verifierId,
  });

  factory VerificationRequest.fromJson(Map<String, dynamic> json) => _$VerificationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationRequestToJson(this);
}
