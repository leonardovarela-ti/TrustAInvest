import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/verifier.dart';
import '../models/verification_request.dart';
import '../models/document.dart';
import 'auth_service.dart';

class ApiService {
  late final String _baseUrl;
  final AuthService _authService;
  
  ApiService(this._authService) {
    _baseUrl = dotenv.get('API_URL', fallback: 'http://localhost:8080/api');
  }
  
  // Helper method to get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  
  // Handle HTTP errors
  void _handleError(http.Response response) {
    if (response.statusCode >= 400) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'API Error: ${response.statusCode}');
    }
  }
  
  // Get all verification requests with optional filters
  Future<List<VerificationRequest>> getVerificationRequests({
    String? status,
    String? searchQuery,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }
    
    final uri = Uri.parse('$_baseUrl/verification-requests').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );
    
    _handleError(response);
    
    final List<dynamic> data = json.decode(response.body)['data'];
    return data.map((item) => VerificationRequest.fromJson(item)).toList();
  }
  
  // Get verification request by ID
  Future<VerificationRequest> getVerificationRequest(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/verification-requests/$id'),
      headers: await _getHeaders(),
    );
    
    _handleError(response);
    
    final data = json.decode(response.body);
    return VerificationRequest.fromJson(data);
  }
  
  // Get documents for a verification request
  Future<List<Document>> getDocuments(String requestId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/verification-requests/$requestId/documents'),
      headers: await _getHeaders(),
    );
    
    _handleError(response);
    
    final List<dynamic> data = json.decode(response.body)['data'];
    return data.map((item) => Document.fromJson(item)).toList();
  }
  
  // Get documents for a verification request (alias for getDocuments)
  Future<List<Document>> getDocumentsForVerificationRequest(String requestId) async {
    return getDocuments(requestId);
  }
  
  // Verify a document
  Future<Document> verifyDocument(String documentId, bool isVerified, {String? notes}) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/documents/$documentId/verify'),
      headers: await _getHeaders(),
      body: json.encode({
        'is_verified': isVerified,
        'verification_notes': notes,
      }),
    );
    
    _handleError(response);
    
    final data = json.decode(response.body);
    return Document.fromJson(data);
  }
  
  // Update verification request status
  Future<VerificationRequest> updateVerificationStatus(
    String requestId, 
    String status, 
    {String? rejectionReason}
  ) async {
    final Map<String, dynamic> body = {
      'status': status,
    };
    
    if (status == 'REJECTED' && rejectionReason != null) {
      body['rejection_reason'] = rejectionReason;
    }
    
    final response = await http.patch(
      Uri.parse('$_baseUrl/verification-requests/$requestId/status'),
      headers: await _getHeaders(),
      body: json.encode(body),
    );
    
    _handleError(response);
    
    final data = json.decode(response.body);
    return VerificationRequest.fromJson(data);
  }
  
  // Update verification request status (alias for updateVerificationStatus)
  Future<VerificationRequest> updateVerificationRequestStatus(
    String requestId, 
    KYCStatus status, 
    {String? rejectionReason}
  ) async {
    return updateVerificationStatus(
      requestId, 
      status.toString().split('.').last, 
      rejectionReason: rejectionReason
    );
  }
  
  // Get document download URL
  Future<String> getDocumentDownloadUrl(String documentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/documents/$documentId/download-url'),
      headers: await _getHeaders(),
    );
    
    _handleError(response);
    
    final data = json.decode(response.body);
    return data['url'] as String;
  }
  
  // Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard/stats'),
      headers: await _getHeaders(),
    );
    
    _handleError(response);
    
    return json.decode(response.body);
  }
  
  // Get all verifiers (admin only)
  Future<List<Verifier>> getVerifiers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/verifiers'),
      headers: await _getHeaders(),
    );
    
    _handleError(response);
    
    final List<dynamic> data = json.decode(response.body)['data'];
    return data.map((item) => Verifier.fromJson(item)).toList();
  }
  
  // Create a new verifier (admin only)
  Future<Verifier> createVerifier({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String role = 'VERIFIER',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verifiers'),
      headers: await _getHeaders(),
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
      }),
    );
    
    _handleError(response);
    
    final data = json.decode(response.body);
    return Verifier.fromJson(data);
  }
  
  // Update a verifier (admin only or self)
  Future<Verifier> updateVerifier({
    required String id,
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    bool? isActive,
  }) async {
    final Map<String, dynamic> body = {};
    
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (email != null) body['email'] = email;
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    
    final response = await http.patch(
      Uri.parse('$_baseUrl/verifiers/$id'),
      headers: await _getHeaders(),
      body: json.encode(body),
    );
    
    _handleError(response);
    
    final data = json.decode(response.body);
    return Verifier.fromJson(data);
  }
  
  // Delete a verifier (admin only)
  Future<void> deleteVerifier(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/verifiers/$id'),
      headers: await _getHeaders(),
    );
    
    _handleError(response);
  }
  
  // Change password
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/change-password'),
      headers: await _getHeaders(),
      body: json.encode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    
    _handleError(response);
  }
  
  // Reset verifier password (admin only)
  Future<void> resetVerifierPassword(String verifierId, String newPassword) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verifiers/$verifierId/reset-password'),
      headers: await _getHeaders(),
      body: json.encode({
        'new_password': newPassword,
      }),
    );
    
    _handleError(response);
  }
}
