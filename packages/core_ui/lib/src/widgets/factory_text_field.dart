import 'package:flutter/material.dart';

/// A single-value input — phone, name, promo code. [label] is required and
/// always renders as `InputDecoration.labelText`, never `hintText`: the
/// design system's InputField spec calls for "a persistent visible label —
/// never placeholder-only", so this has no way to construct one without it.
/// Loading/success states aren't separate flags — pass a spinner or check
/// icon as [suffixIcon] the same way an error passes [errorText]; that
/// keeps this widget honest about not owning async state it doesn't run.
///
/// Built on [TextFormField], not [TextField]: [validator] lets this sit
/// inside a `Form` and participate in `_formKey.currentState!.validate()`
/// the same way a hand-rolled `TextFormField` would — it works exactly like
/// a plain text field everywhere else, since `TextFormField` is a strict
/// superset with no Form ancestor required.
class FactoryTextField extends StatelessWidget {
  const FactoryTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.validator,
    this.autovalidateMode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  /// Set to put this field inside a `Form` — same contract as
  /// `TextFormField.validator`. Leave null for a plain field with no Form
  /// ancestor; [errorText] still works either way for an externally-driven
  /// (e.g. server-side) error.
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: obscureText ? 1 : maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      autovalidateMode: autovalidateMode,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
