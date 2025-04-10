import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final bool readOnly;
  final EdgeInsetsGeometry? contentPadding;
  final TextCapitalization textCapitalization;
  final AutovalidateMode autovalidateMode;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.contentPadding,
    this.textCapitalization = TextCapitalization.none,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onBackground,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          focusNode: focusNode,
          onChanged: onChanged,
          onTap: onTap,
          readOnly: readOnly,
          textCapitalization: textCapitalization,
          autovalidateMode: autovalidateMode,
          inputFormatters: inputFormatters,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            contentPadding: contentPadding,
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class CustomPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final AutovalidateMode autovalidateMode;

  const CustomPasswordField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(key: key);

  @override
  State<CustomPasswordField> createState() => _CustomPasswordFieldState();
}

class _CustomPasswordFieldState extends State<CustomPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      validator: widget.validator,
      keyboardType: TextInputType.visiblePassword,
      obscureText: _obscureText,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      autovalidateMode: widget.autovalidateMode,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
    );
  }
}

class CustomDateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final Future<void> Function()? onTap;
  final AutovalidateMode autovalidateMode;

  const CustomDateField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? 'YYYY-MM-DD',
      validator: validator,
      keyboardType: TextInputType.datetime,
      enabled: enabled,
      focusNode: focusNode,
      onChanged: onChanged,
      readOnly: onTap != null,
      onTap: onTap,
      autovalidateMode: autovalidateMode,
      suffixIcon: Icon(
        Icons.calendar_today_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(10),
      ],
    );
  }
}

class CustomPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final AutovalidateMode autovalidateMode;

  const CustomPhoneField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? '(123) 456-7890',
      validator: validator,
      keyboardType: TextInputType.phone,
      enabled: enabled,
      focusNode: focusNode,
      onChanged: onChanged,
      autovalidateMode: autovalidateMode,
      prefixIcon: Icon(
        Icons.phone_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9()-\s]')),
        LengthLimitingTextInputFormatter(14),
      ],
    );
  }
}

class CustomSSNField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final AutovalidateMode autovalidateMode;

  const CustomSSNField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  }) : super(key: key);

  @override
  State<CustomSSNField> createState() => _CustomSSNFieldState();
}

class _CustomSSNFieldState extends State<CustomSSNField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint ?? 'XXX-XX-XXXX',
      validator: widget.validator,
      keyboardType: TextInputType.number,
      obscureText: _obscureText,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      autovalidateMode: widget.autovalidateMode,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(11),
      ],
    );
  }
}
