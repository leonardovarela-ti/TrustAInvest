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
    print('Creating User from JSON: $json');
    
    // Extract values with null checks and type conversion
    final id = json['id']?.toString();
    final username = json['username']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    final phoneNumber = json['phone_number']?.toString() ?? '';
    final firstName = json['first_name']?.toString() ?? '';
    final lastName = json['last_name']?.toString() ?? '';
    final dateOfBirth = json['date_of_birth'] != null 
        ? DateTime.parse(json['date_of_birth'].toString()) 
        : DateTime.now();
    final address = json['address'] != null 
        ? Address.fromJson(json['address']) 
        : Address(
            street: '',
            city: '',
            state: '',
            zipCode: '',
            country: '',
          );
    final ssn = json['ssn']?.toString() ?? '';
    final riskProfile = json['risk_profile']?.toString() ?? '';
    final kycStatus = json['kyc_status']?.toString() ?? 'PENDING';
    final kycVerifiedAt = json['kyc_verified_at'] != null 
        ? DateTime.parse(json['kyc_verified_at'].toString()) 
        : null;
    final isActive = json['is_active'] ?? true;
    final createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at'].toString()) 
        : null;
    final updatedAt = json['updated_at'] != null 
        ? DateTime.parse(json['updated_at'].toString()) 
        : null;
    
    print('Extracted user values:');
    print('ID: $id');
    print('Username: $username');
    print('Email: $email');
    print('Phone: $phoneNumber');
    print('Name: $firstName $lastName');
    print('KYC Status: $kycStatus');
    
    return User(
      id: id,
      username: username,
      email: email,
      phoneNumber: phoneNumber,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      address: address,
      ssn: ssn,
      riskProfile: riskProfile,
      kycStatus: kycStatus,
      kycVerifiedAt: kycVerifiedAt,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
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
    print('Creating Address from JSON: $json');
    
    // Extract values with null checks and type conversion
    final street = json['street']?.toString() ?? '';
    final city = json['city']?.toString() ?? '';
    final state = json['state']?.toString() ?? '';
    final zipCode = json['zip_code']?.toString() ?? '';
    final country = json['country']?.toString() ?? '';
    
    print('Extracted address values:');
    print('Street: $street');
    print('City: $city');
    print('State: $state');
    print('Zip: $zipCode');
    print('Country: $country');
    
    return Address(
      street: street,
      city: city,
      state: state,
      zipCode: zipCode,
      country: country,
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

class LoginResponse {
  final String token;
  final int expiresIn;
  final String userId;
  final String username;
  final String email;

  LoginResponse({
    required this.token,
    required this.expiresIn,
    required this.userId,
    required this.username,
    required this.email,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    print('Creating LoginResponse from JSON: $json');
    
    // Extract values with null checks and type conversion
    final token = json['token']?.toString() ?? '';
    final expiresIn = json['expires_in'] is int 
        ? json['expires_in'] as int 
        : (json['expires_in'] is String 
            ? int.tryParse(json['expires_in'] as String) ?? 86400 
            : 86400);
    final userId = json['user_id']?.toString() ?? '';
    final username = json['username']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    
    print('Extracted values:');
    print('Token: $token');
    print('Expires in: $expiresIn');
    print('User ID: $userId');
    print('Username: $username');
    print('Email: $email');
    
    return LoginResponse(
      token: token,
      expiresIn: expiresIn,
      userId: userId,
      username: username,
      email: email,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'expires_in': expiresIn,
      'user_id': userId,
      'username': username,
      'email': email,
    };
  }
}
