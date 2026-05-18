import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String? text;
  const LoadingWidget({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            const SizedBox(height: 16),
            Text(text!, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }
}