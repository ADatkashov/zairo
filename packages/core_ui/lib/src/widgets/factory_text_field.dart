import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/factory_strings.dart';

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
    this.minLines,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.validator,
    this.autovalidateMode,
    this.inputFormatters,
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

  /// Lines the field occupies while empty. Leave null for [maxLines] to also
  /// be its height; a growing composer (chat) passes 1 with a larger [maxLines].
  final int? minLines;
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

  /// Live input masks/filters, e.g. [KzPhoneInputFormatter].
  final List<TextInputFormatter>? inputFormatters;

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
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: IconButton(
                // A compact button: the default 48 px circle was as tall as the field and
                // stuck out of its right edge.
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                style: IconButton.styleFrom(
                  fixedSize: const Size(36, 36),
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                tooltip: _revealed
                    ? FactoryStrings.of(context).hidePassword
                    : FactoryStrings.of(context).showPassword,
                onPressed: () => setState(() => _revealed = !_revealed),
              ),
              )
            : null);
    return TextFormField(
      controller: w.controller,
      focusNode: w.focusNode,
      enabled: w.enabled,
      readOnly: w.readOnly,
      obscureText: hidden,
      keyboardType: w.keyboardType,
      inputFormatters: w.inputFormatters,
      textInputAction: w.textInputAction,
      maxLines: w.obscureText ? 1 : w.maxLines,
      minLines: w.obscureText ? null : w.minLines,
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
        // The field's own minimum for a suffix is 48 px, which is what made the eye taller than the field.
        suffixIconConstraints: w.suffixIcon == null && w.obscureText ? const BoxConstraints(minWidth: 46, minHeight: 36) : null,
      ),
    );
  }
}
