import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/verifier.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class VerifierManagementScreen extends StatefulWidget {
  const VerifierManagementScreen({super.key});

  @override
  State<VerifierManagementScreen> createState() => _VerifierManagementScreenState();
}

class _VerifierManagementScreenState extends State<VerifierManagementScreen> {
  bool _isLoading = true;
  List<Verifier> _verifiers = [];
  String? _errorMessage;
  
  // Form controllers for adding new verifier
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isAddingVerifier = false;
  
  @override
  void initState() {
    super.initState();
    _loadVerifiers();
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadVerifiers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final verifiers = await apiService.getVerifiers();
      
      if (mounted) {
        setState(() {
          _verifiers = verifiers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load verifiers: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _addVerifier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isAddingVerifier = true;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.createVerifier(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      
      if (mounted) {
        setState(() {
          _isAddingVerifier = false;
        });
        
        // Clear form
        _usernameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        
        // Close dialog
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifier added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload verifiers
        _loadVerifiers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAddingVerifier = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add verifier: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _toggleVerifierStatus(Verifier verifier) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateVerifier(
        id: verifier.id,
        isActive: !verifier.isActive,
      );
      
      // Reload verifiers
      _loadVerifiers();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verifier ${verifier.isActive ? 'deactivated' : 'activated'} successfully'
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update verifier status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _resetPassword(Verifier verifier) async {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reset Password for ${verifier.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter new password:'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPassword = passwordController.text.trim();
                if (newPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a password'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  await apiService.resetVerifierPassword(verifier.id, newPassword);
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reset password: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Reset Password'),
            ),
          ],
        );
      },
    );
  }
  
  void _showAddVerifierDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Verifier'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                          .hasMatch(value)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isAddingVerifier ? null : _addVerifier,
              child: _isAddingVerifier
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Verifier'),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    // Check if current user is admin
    if (currentUser == null || currentUser.role != 'ADMIN') {
      return const Center(
        child: Text(
          'You do not have permission to access this page.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Verifiers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerifiers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null && _verifiers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVerifiers,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _verifiers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No verifiers found',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _showAddVerifierDialog,
                            child: const Text('Add Verifier'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _verifiers.length,
                      itemBuilder: (context, index) {
                        final verifier = _verifiers[index];
                        return _buildVerifierCard(verifier);
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVerifierDialog,
        tooltip: 'Add Verifier',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildVerifierCard(Verifier verifier) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    '${verifier.firstName[0]}${verifier.lastName[0]}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${verifier.firstName} ${verifier.lastName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        verifier.username,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    verifier.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: verifier.isActive ? Colors.green : Colors.red,
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Email', verifier.email),
            _buildInfoRow('Role', verifier.role),
            _buildInfoRow('Created', dateFormat.format(verifier.createdAt)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _resetPassword(verifier),
                  icon: const Icon(Icons.password),
                  label: const Text('Reset Password'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _toggleVerifierStatus(verifier),
                  icon: Icon(
                    verifier.isActive ? Icons.block : Icons.check_circle,
                    color: verifier.isActive ? Colors.red : Colors.green,
                  ),
                  label: Text(
                    verifier.isActive ? 'Deactivate' : 'Activate',
                    style: TextStyle(
                      color: verifier.isActive ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
