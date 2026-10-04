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
class FactoryTextField extends StatefulWidget {
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
  State<FactoryTextField> createState() => _FactoryTextFieldState();
}

class _FactoryTextFieldState extends State<FactoryTextField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final hidden = w.obscureText && !_revealed;
    // Password fields get a show/hide eye unless the caller supplied its own
    // suffixIcon.
    final suffix = w.suffixIcon ??
        (w.obscureText
            ? IconButton(
                icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                tooltip: _revealed ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _revealed = !_revealed),
              )
            : null);
    return TextFormField(
      controller: w.controller,
      focusNode: w.focusNode,
      enabled: w.enabled,
      readOnly: w.readOnly,
      obscureText: hidden,
      keyboardType: w.keyboardType,
      textInputAction: w.textInputAction,
      maxLines: w.obscureText ? 1 : w.maxLines,
      onChanged: w.onChanged,
      onFieldSubmitted: w.onSubmitted,
      validator: w.validator,
      autovalidateMode: w.autovalidateMode,
      decoration: InputDecoration(
        labelText: w.label,
        hintText: w.hint,
        errorText: w.errorText,
        prefixIcon: w.prefixIcon,
        suffixIcon: suffix,
      ),
    );
  }
}
