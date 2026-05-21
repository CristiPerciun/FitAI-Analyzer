import 'package:fitai_analyzer/models/home_widget_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyHomeWidgetType = 'home_widget_type';

/// Widget scelto dall'utente da mostrare in Home (sotto i pilastri).
/// Caricamento async da SharedPreferences per ripristino dopo riavvio app.
final homeWidgetPreferenceProvider =
    AsyncNotifierProvider<HomeWidgetPreferenceNotifier, HomeWidgetType?>(
  HomeWidgetPreferenceNotifier.new,
);

class HomeWidgetPreferenceNotifier extends AsyncNotifier<HomeWidgetType?> {
  @override
  Future<HomeWidgetType?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return HomeWidgetType.fromStorageKey(prefs.getString(_keyHomeWidgetType));
  }

  Future<void> setWidget(HomeWidgetType? type) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == null) {
      await prefs.remove(_keyHomeWidgetType);
    } else {
      await prefs.setString(_keyHomeWidgetType, type.name);
    }
    state = AsyncData(type);
  }

  Future<void> clearWidget() => setWidget(null);
}
