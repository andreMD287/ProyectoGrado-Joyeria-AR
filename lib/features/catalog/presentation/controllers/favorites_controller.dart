import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia local en el dispositivo, sin necesidad de registro.
final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, Set<String>>(
      FavoritesController.new,
    );

class FavoritesController extends AsyncNotifier<Set<String>> {
  static const _key = 'joyeria_ar_favoritos_v1';
  final _prefs = SharedPreferencesAsync();

  @override
  Future<Set<String>> build() async =>
      (await _prefs.getStringList(_key) ?? <String>[]).toSet();

  Future<void> toggle(String pieceId) async {
    final previous = Set<String>.from(await future);
    final updated = Set<String>.from(previous);
    if (!updated.add(pieceId)) {
      updated.remove(pieceId);
    }
    state = AsyncData(updated);
    try {
      await _prefs.setStringList(_key, updated.toList()..sort());
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
