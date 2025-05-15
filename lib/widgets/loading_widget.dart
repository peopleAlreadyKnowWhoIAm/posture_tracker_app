import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final bool isLoading;
  final Widget? child;

  const LoadingWidget({super.key, required this.isLoading, this.child});

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      if (child == null) {
        return const SizedBox.shrink(); // Return nothing if not loading
      }
      return child!;
    }

    return Stack(
      children: [
        if (child != null) child!,
        Container(color: Colors.black.withValues(alpha: 0.3)),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
