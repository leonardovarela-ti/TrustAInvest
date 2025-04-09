import 'package:flutter/material.dart';

/// Email validator
FormFieldValidator<String> emailValidator() {
  return (value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    
    return null;
  };
}

/// Password validator
FormFieldValidator<String> passwordValidator({int minLength = 8}) {
  return (value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    
    // Optional: Add more password strength requirements
    // bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
    // bool hasLowercase = value.contains(RegExp(r'[a-z]'));
    // bool hasDigits = value.contains(RegExp(r'[0-9]'));
    // bool hasSpecialCharacters = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    // if (!hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
    //   return 'Password must include uppercase, lowercase, number and special character';
    // }
    
    return null;
  };
}

/// Required field validator
FormFieldValidator<String> requiredValidator(String fieldName) {
  return (value) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  };
}

/// Phone number validator
FormFieldValidator<String> phoneValidator() {
  return (value) {
    if (value == null || value.isEmpty) {
      return null; // Phone might be optional
    }
    
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    
    return null;
  };
}

/// Username validator
FormFieldValidator<String> usernameValidator() {
  return (value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    
    return null;
  };
}

/// Combine multiple validators
FormFieldValidator<String> composeValidators(List<FormFieldValidator<String>> validators) {
  return (value) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) {
        return result;
      }
    }
    return null;
  };
}
