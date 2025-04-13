import 'package:intl/intl.dart';

class User {
  final String? id;
  final String username;
  final String email;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final Address address;
  final String ssn;
  final String riskProfile;
  final String kycStatus;
  final DateTime? kycVerifiedAt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool acceptTerms;

  User({
    this.id,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.address,
    required this.ssn,
    this.riskProfile = '',
    this.kycStatus = 'PENDING',
    this.kycVerifiedAt,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.acceptTerms = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      address: Address.fromJson(json['address']),
      ssn: json['ssn'] ?? '',
      riskProfile: json['risk_profile'] ?? '',
      kycStatus: json['kyc_status'] ?? 'PENDING',
      kycVerifiedAt: json['kyc_verified_at'] != null
          ? DateTime.parse(json['kyc_verified_at'])
          : null,
      isActive: json['is_active'] ?? true,
      createdAt:
          json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt:
          json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return {
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateFormat.format(dateOfBirth),
      'address': address.toJson(),
      'ssn': ssn,
      'risk_profile': riskProfile,
    };
  }

  Map<String, dynamic> toRegistrationJson() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return {
      'username': username,
      'email': email,
      'password': '', // This will be set separately
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateFormat.format(dateOfBirth),
      'address': address.toJson(),
      'ssn': ssn,
      'risk_profile': riskProfile,
      'accept_terms': acceptTerms,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    Address? address,
    String? ssn,
    String? riskProfile,
    String? kycStatus,
    DateTime? kycVerifiedAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? acceptTerms,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      ssn: ssn ?? this.ssn,
      riskProfile: riskProfile ?? this.riskProfile,
      kycStatus: kycStatus ?? this.kycStatus,
      kycVerifiedAt: kycVerifiedAt ?? this.kycVerifiedAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acceptTerms: acceptTerms ?? this.acceptTerms,
    );
  }
}

class Address {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zip_code'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'country': country,
    };
  }

  Address copyWith({
    String? street,
    String? city,
    String? state,
    String? zipCode,
    String? country,
  }) {
    return Address(
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
    );
  }
}

class RegistrationResponse {
  final String id;
  final String? username;
  final String? email;
  final String? status;
  final String message;

  RegistrationResponse({
    required this.id,
    this.username,
    this.email,
    this.status,
    required this.message,
  });

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      id: json['id'] ?? json['user_id'] ?? '',
      username: json['username'],
      email: json['email'],
      status: json['status'] ?? 'PENDING',
      message: json['message'] ?? 'Registration successful',
    );
  }
}
