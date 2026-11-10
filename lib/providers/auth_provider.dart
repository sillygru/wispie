import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

const _unchanged = Object();

class AuthState {
  final String? username;
  final bool isLoading;
  final String? error;

  AuthState({this.username, this.isLoading = false, this.error});

  bool get isAuthenticated => username != null;

  AuthState copyWith({
    Object? username = _unchanged,
    bool? isLoading,
    Object? error = _unchanged,
  }) {
    return AuthState(
      username:
          identical(username, _unchanged) ? this.username : username as String?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unchanged) ? this.error : error as String?,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  Future<void> _mutationChain = Future<void>.value();
  int _stateRevision = 0;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    _loadUser();
    return AuthState();
  }

  Future<void> _loadUser() async {
    final revision = _stateRevision;
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (revision == _stateRevision) {
      state = state.copyWith(username: username);
    }
  }

  Future<void> setDisplayName(String username) => _serializeMutation(() async {
        state = state.copyWith(isLoading: true, error: null);
        final revision = ++_stateRevision;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', username);
          if (revision == _stateRevision) {
            state = state.copyWith(username: username, isLoading: false);
          }
        } catch (e) {
          if (revision == _stateRevision) {
            state = state.copyWith(isLoading: false, error: e.toString());
          }
        }
      });

  Future<void> updateUsername(String newUsername) =>
      _serializeMutation(() async {
        state = state.copyWith(isLoading: true, error: null);
        final revision = ++_stateRevision;
        try {
          final updatedName = await _authService.updateUsername(newUsername);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', updatedName);
          if (revision == _stateRevision) {
            state = state.copyWith(username: updatedName, isLoading: false);
          }
        } catch (e) {
          if (revision == _stateRevision) {
            state = state.copyWith(isLoading: false, error: e.toString());
          }
          rethrow;
        }
      });

  Future<void> _serializeMutation(Future<void> Function() mutation) {
    final result = _mutationChain.then((_) => mutation());
    _mutationChain = result.catchError((Object _) {});
    return result;
  }
}

final authServiceProvider = Provider((ref) => AuthService());

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class PreloadedAuthNotifier extends AuthNotifier {
  final String? initialUsername;

  PreloadedAuthNotifier(this.initialUsername);

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    return AuthState(username: initialUsername);
  }
}
