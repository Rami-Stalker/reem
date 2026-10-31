import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The finish she has chosen for her wardrobe — matte white, light oak or
/// walnut. Kept on the device: it is how her wardrobe looks to her, not a
/// fact about it the server needs.
class ClosetFinishNotifier extends Notifier<ArmoireFinish> {
  // l10n-ignore: a storage key
  static const _key = 'closet.finish.v1';

  @override
  ArmoireFinish build() {
    _restore();
    return ArmoireFinish.oak;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      for (final finish in ArmoireFinish.values) {
        if (finish.name == saved && finish != state) state = finish;
      }
    } catch (_) {
      // No stored choice, or no storage: the default finish is fine.
    }
  }

  Future<void> choose(ArmoireFinish finish) async {
    state = finish;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, finish.name);
    } catch (_) {
      // Losing the choice costs a tap next time; a failed write is not worth
      // more than that.
    }
  }
}

final closetFinishProvider = NotifierProvider<ClosetFinishNotifier, ArmoireFinish>(
  ClosetFinishNotifier.new,
);
