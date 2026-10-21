import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Spacing that belongs to a section, and goes when the section goes.
///
/// Many sections in this app draw nothing when they have nothing to say — a
/// closet panel for a shopper with no closet, a fit line for a size nobody
/// has bought. A `SizedBox` beside such a section cannot know whether it
/// drew anything, so it always reserves its height, and a run of empty
/// sections stacks into a band of blank page. This measures the child first:
/// [before] and [after] are added around it only when it has height.
class DsCollapsingGap extends SingleChildRenderObjectWidget {
  const DsCollapsingGap({
    super.key,
    this.before = 0,
    this.after = 0,
    required Widget super.child,
  });

  /// Space above the child, when the child drew anything.
  final double before;

  /// Space below the child, when the child drew anything.
  final double after;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderDsCollapsingGap(before, after);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDsCollapsingGap renderObject,
  ) {
    renderObject
      ..before = before
      ..after = after;
  }
}

/// The render object behind [DsCollapsingGap].
class RenderDsCollapsingGap extends RenderShiftedBox {
  RenderDsCollapsingGap(this._before, this._after) : super(null);

  double _before;
  double _after;

  set before(double value) {
    if (_before == value) return;
    _before = value;
    markNeedsLayout();
  }

  set after(double value) {
    if (_after == value) return;
    _after = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    // Width passes through as given, so the child keeps its full row (and
    // its side, in RTL); only the floor on height is lifted, so an empty
    // section can be empty.
    child.layout(constraints.copyWith(minHeight: 0), parentUsesSize: true);
    final height = child.size.height;
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      height == 0 ? 0 : _before,
    );
    size = constraints.constrain(
      Size(child.size.width, height == 0 ? 0 : _before + height + _after),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _wrap(child?.getMinIntrinsicHeight(width) ?? 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _wrap(child?.getMaxIntrinsicHeight(width) ?? 0);

  double _wrap(double height) => height == 0 ? 0 : _before + height + _after;
}
