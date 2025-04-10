class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  // Username validation
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.length > 30) {
      return 'Username must be less than 30 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.length > 50) {
      return 'Name must be less than 50 characters';
    }
    return null;
  }

  // Phone number validation
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10) {
      return 'Phone number must have at least 10 digits';
    }
    return null;
  }

  // Date of birth validation
  static String? validateDateOfBirth(String? value) {
    if (value == null || value.isEmpty) {
      return 'Date of birth is required';
    }
    
    try {
      final date = DateTime.parse(value);
      final now = DateTime.now();
      final age = now.year - date.year - 
          (now.month > date.month || 
          (now.month == date.month && now.day >= date.day) ? 0 : 1);
      
      if (age < 18) {
        return 'You must be at least 18 years old';
      }
      if (age > 120) {
        return 'Please enter a valid date of birth';
      }
    } catch (e) {
      return 'Please enter a valid date in YYYY-MM-DD format';
    }
    
    return null;
  }

  // SSN validation
  static String? validateSSN(String? value) {
    if (value == null || value.isEmpty) {
      return 'SSN is required';
    }
    
    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (digitsOnly.length != 9) {
      return 'SSN must be 9 digits';
    }
    
    // Check for obviously invalid SSNs
    if (digitsOnly == '000000000' || 
        digitsOnly == '111111111' || 
        digitsOnly == '222222222' || 
        digitsOnly == '333333333' || 
        digitsOnly == '444444444' || 
        digitsOnly == '555555555' || 
        digitsOnly == '666666666' || 
        digitsOnly == '777777777' || 
        digitsOnly == '888888888' || 
        digitsOnly == '999999999' || 
        digitsOnly.startsWith('000') || 
        digitsOnly.startsWith('666') || 
        digitsOnly.startsWith('9')) {
      return 'Please enter a valid SSN';
    }
    
    return null;
  }

  // Address validation
  static String? validateAddressField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (value.length > 100) {
      return '$fieldName must be less than 100 characters';
    }
    return null;
  }

  // Zip code validation
  static String? validateZipCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Zip code is required';
    }
    
    // Basic US zip code validation (5 digits or 5+4)
    if (!RegExp(r'^\d{5}(-\d{4})?$').hasMatch(value)) {
      return 'Please enter a valid zip code';
    }
    
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
