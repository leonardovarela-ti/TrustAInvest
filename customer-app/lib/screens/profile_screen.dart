import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../widgets/loading_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          final user = authService.currentUser;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Check if address is empty
          final isAddressEmpty = user.address.street.isEmpty && 
                                user.address.city.isEmpty && 
                                user.address.state.isEmpty && 
                                user.address.zipCode.isEmpty && 
                                user.address.country.isEmpty;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('Personal Information', [
                  _buildInfoRow('Username', user.username),
                  _buildInfoRow('Email', user.email),
                  _buildInfoRow('Full Name', '${user.firstName} ${user.lastName}'),
                  _buildInfoRow('Phone', user.phoneNumber),
                  _buildInfoRow('Date of Birth', _dateFormat.format(user.dateOfBirth)),
                ]),
                const SizedBox(height: 24),
                _buildSection('Address', [
                  if (isAddressEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Address information is not available. Please update your profile.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else ...[
                    _buildInfoRow('Street', user.address.street),
                    _buildInfoRow('City', user.address.city),
                    _buildInfoRow('State', user.address.state),
                    _buildInfoRow('ZIP Code', user.address.zipCode),
                    _buildInfoRow('Country', user.address.country),
                  ],
                ]),
                const SizedBox(height: 24),
                _buildSection('Account Information', [
                  _buildInfoRow('Risk Profile', user.riskProfile),
                  _buildInfoRow('KYC Status', user.kycStatus),
                  _buildInfoRow('Created At', user.createdAt != null ? _dateFormat.format(user.createdAt!) : null),
                  if (user.updatedAt != null)
                    _buildInfoRow('Last Updated', _dateFormat.format(user.updatedAt!)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatValue(value),
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'not set/provided';
    }
    return value;
  }
} 