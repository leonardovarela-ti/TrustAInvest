import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Form controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _ssnController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController(text: 'United States');
  
  // Formatters
  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(###) ###-####',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  final _ssnFormatter = MaskTextInputFormatter(
    mask: '###-##-####',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  final _dateFormatter = MaskTextInputFormatter(
    mask: '####-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _ssnController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goToPreviousStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildAccountInfoStep(),
                    _buildPersonalInfoStep(),
                    _buildAddressStep(),
                    _buildReviewStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _currentStep
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAccountInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your TrustAInvest account credentials',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 24),
          
          CustomTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'Enter a unique username',
            validator: Validators.validateUsername,
            keyboardType: TextInputType.text,
            prefixIcon: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          CustomTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'Enter your email address',
            validator: Validators.validateEmail,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(
              Icons.email_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          CustomPasswordField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create a strong password',
            validator: Validators.validatePassword,
          ),
          
          CustomPasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            validator: (value) => Validators.validateConfirmPassword(
              value,
              _passwordController.text,
            ),
          ),
          
          const SizedBox(height: 24),
          
          CustomButton(
            text: 'Continue',
            onPressed: _validateAndContinue,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about yourself',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 24),
          
          CustomTextField(
            controller: _firstNameController,
            label: 'First Name',
            hint: 'Enter your first name',
            validator: Validators.validateName,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
          ),
          
          CustomTextField(
            controller: _lastNameController,
            label: 'Last Name',
            hint: 'Enter your last name',
            validator: Validators.validateName,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
          ),
          
          CustomPhoneField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '(123) 456-7890',
            validator: Validators.validatePhoneNumber,
          ),
          
          CustomDateField(
            controller: _dobController,
            label: 'Date of Birth',
            hint: 'YYYY-MM-DD',
            validator: Validators.validateDateOfBirth,
            onTap: _selectDate,
          ),
          
          CustomSSNField(
            controller: _ssnController,
            label: 'Social Security Number',
            hint: 'XXX-XX-XXXX',
            validator: Validators.validateSSN,
          ),
          
          const SizedBox(height: 24),
          
          CustomButton(
            text: 'Continue',
            onPressed: _validateAndContinue,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAddressStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Address Information',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide your residential address',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 24),
          
          CustomTextField(
            controller: _streetController,
            label: 'Street Address',
            hint: 'Enter your street address',
            validator: (value) => Validators.validateAddressField(value, 'Street address'),
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
          ),
          
          CustomTextField(
            controller: _cityController,
            label: 'City',
            hint: 'Enter your city',
            validator: (value) => Validators.validateAddressField(value, 'City'),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.words,
          ),
          
          CustomTextField(
            controller: _stateController,
            label: 'State/Province',
            hint: 'Enter your state or province',
            validator: (value) => Validators.validateAddressField(value, 'State'),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.words,
          ),
          
          CustomTextField(
            controller: _zipCodeController,
            label: 'Zip/Postal Code',
            hint: 'Enter your zip code',
            validator: Validators.validateZipCode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
          ),
          
          CustomTextField(
            controller: _countryController,
            label: 'Country',
            hint: 'Enter your country',
            validator: (value) => Validators.validateAddressField(value, 'Country'),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.words,
          ),
          
          const SizedBox(height: 24),
          
          CustomButton(
            text: 'Continue',
            onPressed: _validateAndContinue,
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Information',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review your information before submitting',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 24),
          
          _buildReviewSection(
            'Account Information',
            [
              {'Username': _usernameController.text},
              {'Email': _emailController.text},
            ],
          ),
          
          _buildReviewSection(
            'Personal Information',
            [
              {'First Name': _firstNameController.text},
              {'Last Name': _lastNameController.text},
              {'Phone Number': _phoneController.text},
              {'Date of Birth': _dobController.text},
              {'SSN': _getMaskedSSN(_ssnController.text)},
            ],
          ),
          
          _buildReviewSection(
            'Address',
            [
              {'Street': _streetController.text},
              {'City': _cityController.text},
              {'State': _stateController.text},
              {'Zip Code': _zipCodeController.text},
              {'Country': _countryController.text},
            ],
          ),
          
          const SizedBox(height: 24),
          
          CustomButton(
            text: 'Submit Registration',
            onPressed: _submitRegistration,
            isLoading: _isLoading,
          ),
          
          const SizedBox(height: 16),
          
          CustomButton(
            text: 'Edit Information',
            onPressed: _goToPreviousStep,
            isOutlined: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewSection(String title, List<Map<String, String>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                final entry = item.entries.first;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                              ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
  
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }
  
  void _validateAndContinue() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep < 3) {
        setState(() {
          _currentStep++;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }
  
  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }
  
  Future<void> _submitRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Create user object
        final user = User(
          username: _usernameController.text,
          email: _emailController.text,
          phoneNumber: _phoneFormatter.getUnmaskedText(),
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          dateOfBirth: DateFormat('yyyy-MM-dd').parse(_dobController.text),
          address: Address(
            street: _streetController.text,
            city: _cityController.text,
            state: _stateController.text,
            zipCode: _zipCodeController.text,
            country: _countryController.text,
          ),
          ssn: _ssnFormatter.getUnmaskedText(),
        );
        
        // Register user
        final response = await apiService.registerUser(
          user,
          _passwordController.text,
        );
        
        // Save registration response
        await authService.saveRegistrationResponse(response);
        
        // Show success dialog
        if (mounted) {
          _showSuccessDialog(response);
        }
      } catch (e) {
        // Show error dialog
        if (mounted) {
          _showErrorDialog(e.toString());
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  
  void _showSuccessDialog(RegistrationResponse response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registration Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(response.message),
            const SizedBox(height: 16),
            Text(
              'Your account is now pending KYC verification. You will receive an email when your account is verified.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/welcome',
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Failed'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to safely mask SSN
  String _getMaskedSSN(String ssn) {
    if (ssn.isEmpty) {
      return '***-**-****';
    }
    
    // Remove any non-digit characters
    final digitsOnly = ssn.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length >= 4) {
      final lastFour = digitsOnly.substring(digitsOnly.length - 4);
      return '***-**-$lastFour';
    } else {
      // Not enough digits for masking, return as is
      return ssn;
    }
  }
}
