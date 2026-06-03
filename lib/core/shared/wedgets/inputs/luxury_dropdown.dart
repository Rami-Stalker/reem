import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

class LuxuryDropdown<T>
    extends StatefulWidget {
  final List<T> items;
  final T value;
  final Function(T?) onChanged;

  const LuxuryDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  State<LuxuryDropdown<T>>
      createState() =>
          _LuxuryDropdownState<T>();
}

class _LuxuryDropdownState<T>
    extends State<LuxuryDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    return DsGlassCard(
      borderRadius: 24,

      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: widget.value,

          borderRadius:
              BorderRadius.circular(
                  24),

          dropdownColor:
              Colors.white,

          isExpanded: true,

          items: widget.items.map(
            (e) {
              return DropdownMenuItem<T>(
                value: e,

                child: Text(
                  e.toString(),
                ),
              );
            },
          ).toList(),

          onChanged:
              widget.onChanged,
        ),
      ),
    );
  }
}