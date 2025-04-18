import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_button.dart';
import '../widgets/error_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('LoginScreen initialized');
  }

  @override
  void dispose() {
    print('LoginScreen disposed');
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    print('Login button pressed');
    print('Username: ${_usernameController.text}');
    print('Form validation state: ${_formKey.currentState?.validate()}');

    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    setState(() => _isLoading = true);
    print('Loading state set to true');

    try {
      print('Getting API and Auth services');
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      print('API Base URL: ${apiService.baseUrl}');
      print('Attempting login with username: ${_usernameController.text}');
      
      // Attempt login
      print('Sending login request...');
      final loginResponse = await apiService.login(
        _usernameController.text,
        _passwordController.text,
      );
      
      print('Login response received:');
      print('Token: ${loginResponse.token}');
      print('UserId: ${loginResponse.userId}');
      print('Username: ${loginResponse.username}');
      print('Email: ${loginResponse.email}');

      // Save auth token
      print('Saving auth token...');
      await authService.saveToken(loginResponse.token);
      print('Saving user ID...');
      await authService.saveUserId(loginResponse.userId);

      // Get user profile
      print('Getting user profile...');
      final user = await apiService.getCurrentUser(loginResponse.token);
      print('User profile received:');
      print('Username: ${user.username}');
      print('Email: ${user.email}');
      print('KYC Status: ${user.kycStatus}');
      
      print('Saving user data...');
      await authService.saveUserData(user);

      if (mounted) {
        print('Navigating to profile screen...');
        Navigator.pushReplacementNamed(context, '/profile');
      }
    } on ApiException catch (e) {
      print('API Exception caught:');
      print('Status code: ${e.statusCode}');
      print('Message: ${e.message}');
      if (e.stackTrace != null) {
        print('Stack trace: ${e.stackTrace}');
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Login Failed',
            message: e.message,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Unexpected error during login:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Login Failed',
            message: 'Unexpected error: ${e.toString()}',
          ),
        );
      }
    } finally {
      if (mounted) {
        print('Setting loading state to false');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building LoginScreen');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _usernameController,
                  label: 'Username',
                  validator: (value) {
                    print('Validating username: $value');
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: true,
                  validator: (value) {
                    print('Validating password: ${value?.length ?? 0} characters');
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                  text: 'Login',
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    print('Register button pressed');
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text('Don\'t have an account? Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 