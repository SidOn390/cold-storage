import 'package:flutter/material.dart';

class InfoKvRow extends StatelessWidget {
  const InfoKvRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 120,
  });
  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text('$label: ', style: text.labelMedium),
        ),
        Flexible(child: Text(value.toUpperCase(), style: text.bodyMedium)),
      ],
    );
  }
}
