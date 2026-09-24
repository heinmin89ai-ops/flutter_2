import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money.dart';

/// Text field whose value is a kyat amount typed by hand and read back as pya.
///
/// The whole app stores integer pya; only here does a decimal point exist. The
/// input formatter allows digits and dots freely, and [kyatToPya] does the actual
/// accepting: a third decimal or a second dot is reported as an error rather than
/// rounded, because "120.505" is a typo and silently turning it into 120.50 is how
/// a receipt stops matching the shelf.
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialPya,
    this.suffix,
    this.helper,
    this.allowEmpty = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final String label;
  final String? suffix;
  final String? helper;

  /// Called with the parsed pya value, or `null` when the field is empty or
  /// unparseable. `null` on empty is deliberate: a blank wholesale price means
  /// "no wholesale price", which is not the same as 0.
  final ValueChanged<Pya?> onChanged;

  final Pya? initialPya;

  /// When false, an empty field shows a validation error.
  final bool allowEmpty;

  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialPya == null ? '' : formatMoney(widget.initialPya!),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = widget.allowEmpty ? null : 'Required');
      widget.onChanged(null);
      return;
    }
    final pya = kyatToPya(trimmed);
    if (pya == null) {
      setState(() => _error = 'Enter a number, up to two decimals');
      widget.onChanged(null);
      return;
    }
    setState(() => _error = null);
    widget.onChanged(pya);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: widget.onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      // Digits and dots only. `-` is excluded because no price here is negative,
      // and a minus would become a credit note the schema has no column for.
      // Parsing and rejecting is `kyatToPya`'s job, not a formatter's.
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        suffixText: widget.suffix,
        errorText: _error,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: _parse,
      onFieldSubmitted: widget.onSubmitted == null
          ? null
          : (_) => widget.onSubmitted!.call(),
    );
  }
}
