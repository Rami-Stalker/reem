import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Reports its child's height as it changes.
///
/// One frame behind by construction — the size is only known once the child
/// has been laid out — which is why [BottomBarInset] starts from an estimate
/// rather than from zero.
class MeasuredHeight extends SingleChildRenderObjectWidget {
  const MeasuredHeight({
    super.key,
    required this.onHeight,
    required Widget super.child,
  });

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderMeasuredHeight).onHeight = onHeight;
  }
}

class _RenderMeasuredHeight extends RenderProxyBox {
  _RenderMeasuredHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_reported == height) return;
    _reported = height;
    // Never during layout: the listener moves a `MediaQuery` above half the
    // app, and rebuilding from inside `performLayout` is a framework error.
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}

/// Makes the page below a floating bottom bar aware of the bar.
///
/// The buyer's bar is a glass rail drawn *over* the page — `extendBody: true` —
/// which is the design and worth keeping: the feed scrolling under frosted
/// glass is most of what the bottom of the app looks like. What it cost was
/// everything that sits at the bottom of a page: «افتحي أول غرفة», the new-room
/// button, «تسجيل الدخول» and «إنشاء حساب» on the guest profile were all drawn
/// underneath it and could not be reached.
///
/// So the bar's measured height is handed to the page as its bottom inset.
/// `padding` is what `SafeArea` and an unpadded `ListView` consume;
/// `viewPadding` is what `Scaffold` measures a floating action button against.
/// Both are *replaced* rather than added to, because the rail already carries
/// the system inset inside itself and covers that strip of screen.
class BottomBarInset extends StatelessWidget {
  const BottomBarInset({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = height <= media.padding.bottom ? media.padding.bottom : height;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: bottom),
        viewPadding: media.viewPadding.copyWith(bottom: bottom),
      ),
      child: child,
    );
  }
}
