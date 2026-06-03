import 'package:flutter/material.dart';

import '../../shared/wedgets/backgrounds/feminine_mesh_background.dart';
import '../utilities/extensions/context_extensions.dart';

/// Standard scroll page with feminine mesh background.
class ReemScrollPage extends StatelessWidget {
  const ReemScrollPage({
    super.key,
    required this.slivers,
    this.bottom,
    this.floatingActionButton,
    this.extendBody = true,
  });

  final List<Widget> slivers;
  final Widget? bottom;
  final Widget? floatingActionButton;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBody,
      extendBodyBehindAppBar: true,
      backgroundColor: context.dsColors.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom,
      body: Stack(
        children: [
          const FeminineMeshBackground(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: slivers,
          ),
        ],
      ),
    );
  }
}
