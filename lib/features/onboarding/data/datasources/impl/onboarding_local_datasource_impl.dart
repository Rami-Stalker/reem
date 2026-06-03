import 'package:shared_preferences/shared_preferences.dart';

import '../onboarding_local_datasource.dart';

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const _key = 'onboarding_complete';

  @override
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
