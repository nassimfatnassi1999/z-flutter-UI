import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show ContentType, File, HttpClient, HttpHeaders, SocketException;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/services/mail_launcher_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  debugPrint('API Base URL: ${config.apiBaseUrl}');
  runApp(ZApp(config: config));
}

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
  static const voiceRecord = '/voice-record';
  static const emailPreview = '/email-preview';
  static const history = '/history';
  static const settings = '/settings';
  static const profile = '/profile';
}

class ZApp extends StatefulWidget {
  const ZApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<ZApp> createState() => _ZAppState();
}

class _ZAppState extends State<ZApp> {
  late final ZApi _api;
  final AppSession _session = AppSession();

  @override
  void initState() {
    super.initState();
    _api = ZApi(widget.config, _session);
    unawaited(_session.initialize(_api));
  }

  @override
  Widget build(BuildContext context) {
    return ZScope(
      api: _api,
      session: _session,
      child: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          return MaterialApp(
            title: 'Z',
            debugShowCheckedModeBanner: false,
            theme: ZTheme.light(_session.accentColor.color),
            darkTheme: ZTheme.dark(_session.accentColor.color),
            themeMode: _session.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: _route,
          );
        },
      ),
    );
  }

  Route<void> _route(RouteSettings settings) {
    final name = settings.name ?? AppRoutes.splash;
    if (_isProtectedRoute(name) && !_session.isAuthenticated) {
      return MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.login),
        builder: (_) => const LoginScreen(),
      );
    }
    if (_session.isAuthenticated &&
        (name == AppRoutes.login || name == AppRoutes.register)) {
      return MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.home),
        builder: (_) => const HomeScreen(),
      );
    }

    Widget page;
    switch (name) {
      case AppRoutes.splash:
        page = const SplashScreen();
      case AppRoutes.onboarding:
        page = const OnboardingScreen();
      case AppRoutes.login:
        page = const LoginScreen();
      case AppRoutes.register:
        page = const RegisterScreen();
      case AppRoutes.verifyEmail:
        final email = settings.arguments as String?;
        page = VerifyEmailScreen(email: email ?? '');
      case AppRoutes.home:
        page = const HomeScreen();
      case AppRoutes.voiceRecord:
        final args = settings.arguments as VoiceRecordArgs?;
        page = VoiceRecordScreen(autoStart: args?.autoStart ?? false);
      case AppRoutes.emailPreview:
        page = const EmailPreviewScreen();
      case AppRoutes.history:
        page = const HistoryScreen();
      case AppRoutes.settings:
        page = const SettingsScreen();
      case AppRoutes.profile:
        page = const ProfileScreen();
      default:
        page = _session.isAuthenticated
            ? const HomeScreen()
            : const LoginScreen();
    }
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  bool _isProtectedRoute(String name) {
    return {
      AppRoutes.home,
      AppRoutes.voiceRecord,
      AppRoutes.emailPreview,
      AppRoutes.history,
      AppRoutes.settings,
      AppRoutes.profile,
    }.contains(name);
  }
}

class ZTheme {
  const ZTheme._();

  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF1F1F1F);
  static const muted = Color(0xFF7A7A7A);
  static const canvas = Color(0xFFF8F6F2);
  static const card = Colors.white;

  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static ThemeData light(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme.copyWith(
        primary: accent,
        surface: canvas,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: canvas,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E2DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E2DC)),
        ),
      ),
    );
  }

  static ThemeData dark(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme.copyWith(primary: accent),
      scaffoldBackgroundColor: const Color(0xFF101114),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class ZScope extends InheritedWidget {
  const ZScope({
    super.key,
    required this.api,
    required this.session,
    required super.child,
  });

  final ZApi api;
  final AppSession session;

  static ZScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ZScope>();
    assert(scope != null, 'ZScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(ZScope oldWidget) =>
      api != oldWidget.api || session != oldWidget.session;
}

class AppSession extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _deviceIdKey = 'z.deviceId';
  static const _onboardingCompleteKey = 'z.onboardingComplete';
  static const _themeModeKey = 'z.themeMode';
  static const _accentColorKey = 'z.accentColor';
  static const _languagePreferenceKey = 'z.transcriptionLanguage';
  static const _emailLanguagePreferenceKey = 'z.emailOutputLanguage';
  static const _mailPreferenceKey = 'z.preferredMailApp';
  static const _historyKey = 'z.localHistory';
  static const _accessTokenKey = 'z.auth.accessToken';
  static const _refreshTokenKey = 'z.auth.refreshToken';
  static const _userProfileKey = 'z.auth.user';

  String? accessToken;
  String? refreshToken;
  UserProfile? user;
  String deviceId = '';
  bool onboardingComplete = false;
  bool startupChecked = false;
  bool startupChecking = true;
  String? startupError;
  bool offlineHistory = false;
  ThemeMode themeMode = ThemeMode.system;
  ZAccentColor accentColor = ZAccentColor.blue;
  String selectedTemplate = 'Autre';
  String transcript = '';
  String tone = EmailTone.professional.apiValue;
  SpeechLanguage transcriptionLanguage = SpeechLanguage.auto;
  SpeechLanguage emailOutputLanguage = SpeechLanguage.auto;
  String lastDetectedSpeechLanguage = 'unknown';
  PreferredMailApp preferredMailApp = PreferredMailApp.system;
  GeneratedEmail? generatedEmail;
  final List<EmailDraft> history = [];

  bool get isAuthenticated => accessToken != null;

  Future<void> initialize(ZApi api) async {
    await loadSettings();
    await restoreSession(api);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString(_deviceIdKey) ?? _newDeviceId();
    await prefs.setString(_deviceIdKey, deviceId);
    onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;
    themeMode = _themeModeFromName(
      prefs.getString(_themeModeKey) ?? ThemeMode.system.name,
    );
    accentColor = ZAccentColor.fromCode(
      prefs.getString(_accentColorKey) ?? ZAccentColor.blue.code,
    );
    transcriptionLanguage = SpeechLanguage.fromCode(
      prefs.getString(_languagePreferenceKey) ?? SpeechLanguage.auto.code,
    );
    emailOutputLanguage = SpeechLanguage.fromCode(
      prefs.getString(_emailLanguagePreferenceKey) ?? SpeechLanguage.auto.code,
    );
    preferredMailApp = PreferredMailApp.fromCode(
      prefs.getString(_mailPreferenceKey) ?? PreferredMailApp.system.code,
    );
    history
      ..clear()
      ..addAll(_decodeHistory(prefs.getString(_historyKey)));
    notifyListeners();
  }

  Future<void> restoreSession(ZApi api) async {
    startupChecking = true;
    startupError = null;
    notifyListeners();
    try {
      accessToken = await _secureStorage.read(key: _accessTokenKey);
      refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final cachedUser = await _secureStorage.read(key: _userProfileKey);
      if (cachedUser != null) {
        user = UserProfile.fromJson(
          (jsonDecode(cachedUser) as Map).cast<String, dynamic>(),
        );
      }

      if (accessToken != null) {
        try {
          user = await api.fetchMe(token: accessToken!);
          await _persistAuth();
          await refreshHistory(api);
          return;
        } catch (_) {
          if (refreshToken == null) rethrow;
        }
      }

      if (refreshToken != null) {
        final result = await api.refreshAuth(refreshToken: refreshToken!);
        await authenticate(result, api: api);
      }
    } catch (error) {
      await clearAuth();
      startupError = 'Session expirée. Connectez-vous à nouveau.';
    } finally {
      startupChecking = false;
      startupChecked = true;
      notifyListeners();
    }
  }

  Future<bool> refreshFromApi(ZApi api) async {
    final token = refreshToken;
    if (token == null) return false;
    try {
      final result = await api.refreshAuth(refreshToken: token);
      accessToken = result.accessToken;
      refreshToken = result.refreshToken;
      user = result.user;
      await _persistAuth();
      notifyListeners();
      return true;
    } catch (_) {
      await clearAuth();
      return false;
    }
  }

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  Future<void> authenticate(AuthResult result, {ZApi? api}) async {
    accessToken = result.accessToken;
    refreshToken = result.refreshToken;
    user = result.user;
    await _persistAuth();
    if (api != null) {
      await refreshHistory(api);
    }
    notifyListeners();
  }

  Future<void> clearAuth() async {
    accessToken = null;
    refreshToken = null;
    user = null;
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userProfileKey);
    notifyListeners();
  }

  Future<void> logout(ZApi api) async {
    final token = accessToken;
    if (token != null) {
      try {
        await api.logoutAuth(token: token);
      } catch (_) {}
    }
    await clearAuth();
  }

  Future<void> updateUser(UserProfile value) async {
    user = value;
    await _persistAuth();
    notifyListeners();
  }

  Future<void> refreshHistory(ZApi api) async {
    if (!isAuthenticated) return;
    try {
      final drafts = await api.listDrafts(
        token: accessToken,
        deviceId: deviceId,
      );
      history
        ..clear()
        ..addAll(drafts);
      offlineHistory = false;
      _persistHistory();
    } catch (_) {
      offlineHistory = true;
    }
    notifyListeners();
  }

  void markOfflineHistory() {
    offlineHistory = true;
    notifyListeners();
  }

  Future<void> claimDeviceDrafts(ZApi api) async {
    if (!isAuthenticated) return;
    await api.claimDeviceDrafts(token: accessToken!, deviceId: deviceId);
    await refreshHistory(api);
  }

  void setTemplate(String template) {
    selectedTemplate = template;
    notifyListeners();
  }

  void setTranscript(String value) {
    transcript = value;
    notifyListeners();
  }

  void setLastDetectedSpeechLanguage(String value) {
    lastDetectedSpeechLanguage = value.trim().isEmpty ? 'unknown' : value;
    notifyListeners();
  }

  String get outputLanguageForGeneration => emailOutputLanguage.code;

  String get transcriptLanguageForGeneration {
    if (lastDetectedSpeechLanguage != 'unknown') {
      return lastDetectedSpeechLanguage;
    }
    if (transcriptionLanguage != SpeechLanguage.auto) {
      return transcriptionLanguage.code;
    }
    return 'unknown';
  }

  void setTone(String value) {
    tone = value;
    notifyListeners();
  }

  void applyGeneratedEmail(GeneratedEmail value) {
    generatedEmail = value;
    tone = value.tone.apiValue;
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    themeMode = value;
    notifyListeners();
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_themeModeKey, value.name),
      ),
    );
  }

  void setAccentColor(ZAccentColor value) {
    accentColor = value;
    notifyListeners();
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_accentColorKey, value.code),
      ),
    );
  }

  void setTranscriptionLanguage(SpeechLanguage value) {
    transcriptionLanguage = value;
    notifyListeners();
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_languagePreferenceKey, value.code),
      ),
    );
  }

  void setEmailOutputLanguage(SpeechLanguage value) {
    emailOutputLanguage = value;
    notifyListeners();
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_emailLanguagePreferenceKey, value.code),
      ),
    );
  }

  void setPreferredMailApp(PreferredMailApp value) {
    preferredMailApp = value;
    notifyListeners();
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_mailPreferenceKey, value.code),
      ),
    );
  }

  void setGeneratedEmail(GeneratedEmail value) {
    generatedEmail = value;
    notifyListeners();
  }

  void addDraft(EmailDraft draft) {
    history.insert(0, draft);
    _persistHistory();
    notifyListeners();
  }

  void markDraftDeleted(String id) {
    final index = history.indexWhere((draft) => draft.id == id);
    if (index == -1) return;
    history[index] = history[index].copyWith(status: EmailDraftStatus.deleted);
    _persistHistory();
    notifyListeners();
  }

  void updateDraftStatus(String id, EmailDraftStatus status) {
    final index = history.indexWhere((draft) => draft.id == id);
    if (index == -1) return;
    history[index] = history[index].copyWith(status: status);
    _persistHistory();
    notifyListeners();
  }

  void duplicateDraft(EmailDraft draft) {
    history.insert(
      0,
      draft.copyWith(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        status: EmailDraftStatus.draft,
        createdAt: DateTime.now(),
      ),
    );
    _persistHistory();
    notifyListeners();
  }

  void openDraftInPreview(EmailDraft draft) {
    tone = draft.tone;
    generatedEmail = GeneratedEmail(
      language: '',
      tone: EmailTone.fromApiValue(draft.tone),
      intent: 'Brouillon enregistré',
      subject: draft.subject,
      body: draft.body,
      suggestedRecipient: '',
    );
    notifyListeners();
  }

  void clearHistoryTab(HistoryFilter filter) {
    if (filter == HistoryFilter.deleted) {
      history.removeWhere((draft) => draft.status == EmailDraftStatus.deleted);
    } else {
      for (var i = 0; i < history.length; i++) {
        if (filter.matches(history[i])) {
          history[i] = history[i].copyWith(status: EmailDraftStatus.deleted);
        }
      }
    }
    _persistHistory();
    notifyListeners();
  }

  String _newDeviceId() {
    return 'device-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(999999)}';
  }

  ThemeMode _themeModeFromName(String name) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  List<EmailDraft> _decodeHistory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => EmailDraft.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _persistHistory() {
    final encoded = jsonEncode(
      history.take(50).map((draft) => draft.toJson()).toList(),
    );
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_historyKey, encoded),
      ),
    );
  }

  Future<void> _persistAuth() async {
    if (accessToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    }
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (user != null) {
      await _secureStorage.write(
        key: _userProfileKey,
        value: jsonEncode(user!.toJson()),
      );
    }
  }
}

class ZApi {
  const ZApi(this.config, this.session);

  static const _connectTimeout = Duration(seconds: 10);
  static const _sendTimeout = Duration(seconds: 20);
  static const _receiveTimeout = Duration(seconds: 20);

  final AppConfig config;
  final AppSession session;

  Future<RegisterResult> register({
    required String email,
    required String name,
    required String password,
  }) async {
    _debugLog('AuthApi register request started');
    _debugLog('AuthApi API_BASE_URL used: ${config.apiBaseUrl}');
    final json = await _post('auth/register', {
      'email': email,
      'name': name,
      'password': password,
    });
    return RegisterResult.fromJson(json);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    _debugLog('AuthApi login request started');
    _debugLog('AuthApi API_BASE_URL used: ${config.apiBaseUrl}');
    final json = await _post('auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    final json = await _post('auth/verify-email', {
      'email': email,
      'code': code,
    });
    return AuthResult.fromJson(json);
  }

  Future<void> resendVerificationCode({required String email}) async {
    await _post('auth/resend-verification-code', {'email': email});
  }

  Future<AuthResult> refreshAuth({required String refreshToken}) async {
    final json = await _post('auth/refresh', {'refreshToken': refreshToken});
    return AuthResult.fromJson(json);
  }

  Future<void> logoutAuth({required String token}) async {
    await _post('auth/logout', {}, token: token);
  }

  Future<UserProfile> fetchMe({required String token}) async {
    final json = await _get('users/me', token: token);
    return UserProfile.fromJson(json);
  }

  Future<UserProfile> updateMe({
    required String token,
    required String name,
  }) async {
    final json = await _patch('users/me', {'name': name}, token: token);
    return UserProfile.fromJson(json);
  }

  Future<List<EmailDraft>> listDrafts({
    String? token,
    required String deviceId,
  }) async {
    final json = await _get('drafts', token: token, deviceId: deviceId);
    final items = json['items'] as List? ?? json['drafts'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((item) => EmailDraft.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<void> claimDeviceDrafts({
    required String token,
    required String deviceId,
  }) async {
    await _post('drafts/claim-device-drafts', {
      'deviceId': deviceId,
    }, token: token);
  }

  Future<GeneratedEmail> generateEmail({
    required String transcript,
    String? tone,
    String? customTone,
    String? template,
    String? language,
    String? outputLanguage,
  }) async {
    final payload = {'transcript': transcript};
    if (tone != null && tone != EmailTone.custom.apiValue) {
      payload['tone'] = tone;
    }
    if (customTone != null && customTone.trim().isNotEmpty) {
      payload['customTone'] = customTone.trim();
    }
    if (template != null) payload['template'] = template;
    if (language != null) payload['language'] = language;
    if (outputLanguage != null) payload['outputLanguage'] = outputLanguage;
    final json = await _post('ai/generate-email', payload);
    return GeneratedEmail.fromJson(json);
  }

  Future<SpeechTranscript> transcribeSpeech(
    File audioFile,
    SpeechLanguage language,
  ) async {
    final bytes = await audioFile.readAsBytes();
    final mime = _mimeForPath(audioFile.path);
    _debugLog('SpeechApi audio path: ${audioFile.path}');
    _debugLog('SpeechApi audio file size: ${bytes.length}');
    _debugLog('SpeechApi upload started');

    final boundary = 'z-${DateTime.now().microsecondsSinceEpoch}';
    final request = await HttpClient().postUrl(
      Uri.parse('${config.apiV1}/speech/transcribe'),
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.add(utf8.encode('--$boundary\r\n'));
    request.add(
      utf8.encode(
        'Content-Disposition: form-data; name="language"\r\n\r\n'
        '${language.code}\r\n',
      ),
    );
    request.add(utf8.encode('--$boundary\r\n'));
    request.add(
      utf8.encode(
        'Content-Disposition: form-data; name="audio"; filename="voice.m4a"\r\n'
        'Content-Type: $mime\r\n\r\n',
      ),
    );
    request.add(bytes);
    request.add(utf8.encode('\r\n--$boundary--\r\n'));

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    _debugLog('SpeechApi upload response status: ${response.statusCode}');

    final decoded = jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw StateError(
        decoded['message']?.toString() ?? 'Transcription impossible.',
      );
    }

    final payload =
        (decoded['data'] as Map?)?.cast<String, dynamic>() ?? decoded;
    final transcript = SpeechTranscript.fromJson(payload);
    _debugLog(
      'SpeechApi final transcript state length: ${transcript.transcript.trim().length}',
    );
    _debugLog('SpeechApi selected language: ${language.code}');
    _debugLog('SpeechApi detected language: ${transcript.language}');
    _debugLog('SpeechApi confidence: ${transcript.confidence}');
    return transcript;
  }

  Future<EmailDraft> saveDraft({
    String? token,
    required String deviceId,
    required String subject,
    required String body,
    required String tone,
    required String transcript,
    required String templateKey,
    String? recipient,
  }) async {
    final json = await _post(
      'drafts',
      {
        'recipient': recipient?.trim().isEmpty ?? true
            ? null
            : recipient!.trim(),
        'subject': subject,
        'body': body,
        'tone': tone,
        'transcript': transcript,
        'templateKey': templateKey,
      },
      token: token,
      deviceId: deviceId,
    );
    return EmailDraft.fromJson(json);
  }

  Future<void> markDraftOpenedInMailApp({
    String? token,
    required String deviceId,
    required String draftId,
  }) async {
    await _patch(
      'drafts/$draftId/status',
      {'status': 'opened_in_mail_app'},
      token: token,
      deviceId: deviceId,
    );
  }

  Future<void> updateDraftStatus({
    String? token,
    required String deviceId,
    required String draftId,
    required EmailDraftStatus status,
  }) async {
    await _patch(
      'drafts/$draftId/status',
      {'status': status.apiValue},
      token: token,
      deviceId: deviceId,
    );
  }

  Future<void> deleteDraft({
    String? token,
    required String deviceId,
    required String draftId,
  }) async {
    await _delete('drafts/$draftId', token: token, deviceId: deviceId);
  }

  Future<EmailDraft> duplicateDraft({
    String? token,
    required String deviceId,
    required String draftId,
  }) async {
    final json = await _post(
      'drafts/$draftId/duplicate',
      const {},
      token: token,
      deviceId: deviceId,
    );
    return EmailDraft.fromJson(json);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    String? token,
    String? deviceId,
  }) async {
    return _sendJson('GET', path, const {}, token: token, deviceId: deviceId);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> payload, {
    String? token,
    String? deviceId,
  }) async {
    return _sendJson('POST', path, payload, token: token, deviceId: deviceId);
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, Object?> payload, {
    String? token,
    String? deviceId,
  }) async {
    return _sendJson('PATCH', path, payload, token: token, deviceId: deviceId);
  }

  Future<Map<String, dynamic>> _delete(
    String path, {
    String? token,
    String? deviceId,
  }) async {
    return _sendJson(
      'DELETE',
      path,
      const {},
      token: token,
      deviceId: deviceId,
    );
  }

  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path,
    Map<String, Object?> payload, {
    String? token,
    String? deviceId,
    bool allowRefresh = true,
  }) async {
    final uri = Uri.parse('${config.apiV1}/$path');
    final client = HttpClient()..connectionTimeout = _connectTimeout;

    try {
      final request = await client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (deviceId != null && deviceId.trim().isNotEmpty) {
        request.headers.set('X-Device-Id', deviceId.trim());
      }
      if (method != 'GET' && method != 'DELETE') {
        request.write(jsonEncode(payload));
      }

      final response = await request.close().timeout(_sendTimeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_receiveTimeout);
      _debugLog('Api $method $path response status: ${response.statusCode}');

      final decoded = jsonDecode(text) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 &&
            token != null &&
            allowRefresh &&
            path != 'auth/refresh' &&
            await session.refreshFromApi(this)) {
          return _sendJson(
            method,
            path,
            payload,
            token: session.accessToken,
            deviceId: deviceId,
            allowRefresh: false,
          );
        }
        throw ApiException(
          _messageForError(path, response.statusCode, decoded),
          code: decoded['code'] as String?,
          email: decoded['email'] as String?,
        );
      }
      final data = decoded['data'];
      if (data is List) return {'items': data};
      if (data is Map) return data.cast<String, dynamic>();
      return decoded;
    } on TimeoutException catch (error) {
      _debugLog('Api $method $path timeout/network error: $error');
      throw const ApiException(
        'Impossible de joindre le serveur. Vérifiez l’adresse API et le backend.',
      );
    } on SocketException catch (error) {
      _debugLog('Api $method $path timeout/network error: $error');
      throw const ApiException(
        'Impossible de joindre le serveur. Vérifiez l’adresse API et le backend.',
      );
    } on FormatException catch (error) {
      _debugLog('Api $method $path error type: invalid_json $error');
      throw const ApiException('Erreur inattendue. Réessayez.');
    } on ApiException catch (error) {
      _debugLog('Api $method $path error type: api_error ${error.message}');
      rethrow;
    } catch (error) {
      _debugLog('Api $method $path error type: unknown $error');
      throw const ApiException('Erreur inattendue. Réessayez.');
    } finally {
      client.close(force: true);
    }
  }

  String _messageForError(
    String path,
    int statusCode,
    Map<String, dynamic> decoded,
  ) {
    if (path == 'auth/login' && statusCode == 401) {
      return 'Email ou mot de passe incorrect.';
    }
    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    if (message is List && message.isNotEmpty) {
      return message.map((item) => item.toString()).join(', ');
    }
    return 'Erreur inattendue. Réessayez.';
  }

  String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.mpeg')) return 'audio/mpeg';
    if (lower.endsWith('.mp4')) return 'audio/mp4';
    return 'audio/m4a';
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.email});

  final String message;
  final String? code;
  final String? email;

  @override
  String toString() => message;
}

class VoiceRecordArgs {
  const VoiceRecordArgs({required this.autoStart});
  final bool autoStart;
}

enum VoiceRecordState {
  idle,
  recording,
  transcribing,
  understanding,
  generating,
  completed,
  empty,
  error,
}

enum ZAccentColor {
  blue('blue', 'Blue', Color(0xFF2563EB)),
  orange('orange', 'Orange', Color(0xFFF97316)),
  purple('purple', 'Purple', Color(0xFF7C3AED)),
  green('green', 'Green', Color(0xFF16A34A)),
  black('black', 'Black', Color(0xFF111827));

  const ZAccentColor(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static ZAccentColor fromCode(String code) {
    return values.firstWhere(
      (accent) => accent.code == code,
      orElse: () => ZAccentColor.blue,
    );
  }
}

enum EmailTone {
  professional('professional', 'Professionnel'),
  administrative('administrative', 'Administratif'),
  student('student', 'Étudiant'),
  friendly('friendly', 'Amical'),
  formal('formal', 'Formel'),
  business('business', 'Business'),
  custom('custom', 'Autre');

  const EmailTone(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static EmailTone fromApiValue(String value) {
    final normalized = value.toLowerCase().trim();
    return values.firstWhere(
      (tone) => tone.apiValue == normalized,
      orElse: () => EmailTone.professional,
    );
  }
}

enum PreferredMailApp {
  system('system', 'Système par défaut'),
  gmail('gmail', 'Gmail'),
  outlook('outlook', 'Outlook'),
  protonMail('proton_mail', 'Proton Mail'),
  appleMail('apple_mail', 'Apple Mail'),
  copyOnly('copy_only', 'Copier uniquement');

  const PreferredMailApp(this.code, this.label);

  final String code;
  final String label;

  static PreferredMailApp fromCode(String code) {
    return values.firstWhere(
      (app) => app.code == code,
      orElse: () => PreferredMailApp.system,
    );
  }
}

enum EmailDraftStatus {
  draft('draft', 'Brouillon'),
  scheduled('scheduled', 'Planifié'),
  openedInMailApp('opened_in_mail_app', 'Ouvert dans Mail'),
  deleted('deleted', 'Supprimé');

  const EmailDraftStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static EmailDraftStatus fromApiValue(String value) {
    return values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => EmailDraftStatus.draft,
    );
  }
}

enum HistoryFilter {
  all('Tous'),
  drafts('Brouillons'),
  scheduled('Planifiés'),
  opened('Ouverts dans Mail'),
  deleted('Supprimés');

  const HistoryFilter(this.label);

  final String label;

  bool matches(EmailDraft draft) {
    return switch (this) {
      HistoryFilter.all => draft.status != EmailDraftStatus.deleted,
      HistoryFilter.drafts => draft.status == EmailDraftStatus.draft,
      HistoryFilter.scheduled => draft.status == EmailDraftStatus.scheduled,
      HistoryFilter.opened => draft.status == EmailDraftStatus.openedInMailApp,
      HistoryFilter.deleted => draft.status == EmailDraftStatus.deleted,
    };
  }
}

enum HistorySort {
  recent('Tous'),
  oldest('Planifiés'),
  drafts('Brouillons'),
  sent('Ouverts dans Mail'),
  deleted('Supprimés');

  const HistorySort(this.label);

  final String label;
}

class SpeechLanguage {
  const SpeechLanguage({
    required this.code,
    required this.label,
    required this.detectedLabel,
  });

  final String code;
  final String label;
  final String detectedLabel;

  static const auto = SpeechLanguage(
    code: 'auto',
    label: 'Auto Detect',
    detectedLabel: 'Langue non reconnue.',
  );
  static const fr = SpeechLanguage(
    code: 'fr',
    label: 'Français',
    detectedLabel: '🇫🇷 Français détecté',
  );
  static const en = SpeechLanguage(
    code: 'en',
    label: 'English',
    detectedLabel: '🇬🇧 English detected',
  );
  static const ar = SpeechLanguage(
    code: 'ar',
    label: 'العربية',
    detectedLabel: '🇸🇦 العربية مكتشفة',
  );
  static const de = SpeechLanguage(
    code: 'de',
    label: 'Deutsch',
    detectedLabel: '🇩🇪 Deutsch erkannt',
  );
  static const es = SpeechLanguage(
    code: 'es',
    label: 'Español',
    detectedLabel: '🇪🇸 Español detectado',
  );
  static const it = SpeechLanguage(
    code: 'it',
    label: 'Italiano',
    detectedLabel: '🇮🇹 Italiano rilevato',
  );
  static const pt = SpeechLanguage(
    code: 'pt',
    label: 'Português',
    detectedLabel: '🇵🇹 Português detectado',
  );
  static const nl = SpeechLanguage(
    code: 'nl',
    label: 'Nederlands',
    detectedLabel: '🇳🇱 Nederlands gedetecteerd',
  );
  static const tr = SpeechLanguage(
    code: 'tr',
    label: 'Türkçe',
    detectedLabel: '🇹🇷 Türkçe algılandı',
  );

  static const values = [auto, fr, en, ar, de, es, it, pt, nl, tr];

  String get emptyTranscriptMessage {
    if (this == en) {
      return 'No speech detected. Please try again and speak clearly.';
    }
    if (this == ar) {
      return 'لم يتم اكتشاف أي نص. حاول مرة أخرى وتحدث بوضوح.';
    }
    return 'Aucun texte détecté. Réessayez en parlant plus clairement.';
  }

  static SpeechLanguage fromCode(String code) {
    final normalized = code.trim().toLowerCase().split('-').first;
    return values.firstWhere(
      (language) => language.code == normalized,
      orElse: () => SpeechLanguage.auto,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SpeechLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class SpeechTranscript {
  const SpeechTranscript({
    required this.transcript,
    required this.language,
    required this.confidence,
    required this.duration,
  });

  final String transcript;
  final String language;
  final double confidence;
  final double duration;

  factory SpeechTranscript.fromJson(Map<String, dynamic> json) {
    return SpeechTranscript(
      transcript: json['transcript'] as String? ?? '',
      language: json['language'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
  });

  final String id;
  final String email;
  final String name;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'Utilisateur',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'name': name};
  }
}

class AuthResult {
  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserProfile user;
  final String accessToken;
  final String refreshToken;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      user: UserProfile.fromJson((json['user'] as Map).cast<String, dynamic>()),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }
}

class RegisterResult {
  const RegisterResult({
    required this.requiresEmailVerification,
    required this.email,
  });

  final bool requiresEmailVerification;
  final String email;

  factory RegisterResult.fromJson(Map<String, dynamic> json) {
    return RegisterResult(
      requiresEmailVerification:
          json['requiresEmailVerification'] as bool? ?? true,
      email: json['email'] as String? ?? '',
    );
  }
}

class GeneratedEmail {
  const GeneratedEmail({
    required this.language,
    required this.tone,
    required this.intent,
    required this.subject,
    required this.body,
    required this.suggestedRecipient,
  });

  final String language;
  final EmailTone tone;
  final String intent;
  final String subject;
  final String body;
  final String suggestedRecipient;

  factory GeneratedEmail.fromJson(Map<String, dynamic> json) {
    return GeneratedEmail(
      language: json['language'] as String? ?? '',
      tone: EmailTone.fromApiValue(json['tone'] as String? ?? ''),
      intent:
          json['intent'] as String? ?? json['detectedIntent'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Votre e-mail',
      body: json['body'] as String? ?? '',
      suggestedRecipient:
          json['suggestedRecipient'] as String? ??
          json['suggestedRecipientName'] as String? ??
          '',
    );
  }
}

class EmailDraft {
  const EmailDraft({
    required this.id,
    required this.subject,
    required this.body,
    required this.tone,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String body;
  final String tone;
  final EmailDraftStatus status;
  final DateTime createdAt;

  factory EmailDraft.fromJson(Map<String, dynamic> json) {
    return EmailDraft(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tone: json['tone'] as String? ?? '',
      status: EmailDraftStatus.fromApiValue(json['status'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'body': body,
      'tone': tone,
      'status': status.apiValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  EmailDraft copyWith({
    String? id,
    EmailDraftStatus? status,
    DateTime? createdAt,
  }) {
    return EmailDraft(
      id: id ?? this.id,
      subject: subject,
      body: body,
      tone: tone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      final session = ZScope.of(context).session;
      while (!session.startupChecked && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        !session.onboardingComplete
            ? AppRoutes.onboarding
            : session.isAuthenticated
            ? AppRoutes.home
            : AppRoutes.login,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ZScope.of(context).session;
    return ZScaffold(
      child: Center(
        child: AnimatedBuilder(
          animation: session,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ZLogo(size: 86),
                const SizedBox(height: 22),
                const Text(
                  'Z',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: ZTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Parlez. Z rédige.',
                  style: TextStyle(fontSize: 18, color: ZTheme.muted),
                ),
                const SizedBox(height: 18),
                Text(
                  session.startupChecking
                      ? 'Vérification de la session...'
                      : 'Chargement...',
                  style: const TextStyle(color: ZTheme.muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ZScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const ZLogo(size: 74),
              const SizedBox(height: 28),
              const Text(
                'Parlez. Z comprend et rédige.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  color: ZTheme.ink,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Parlez, Z comprend votre intention, rédige votre e-mail, puis vous l’envoyez.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: ZTheme.muted,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await ZScope.of(context).session.completeOnboarding();
                  navigator.pushReplacementNamed(AppRoutes.login);
                },
                child: const Text('Commencer'),
              ),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await ZScope.of(context).session.completeOnboarding();
                  navigator.pushReplacementNamed(AppRoutes.register);
                },
                child: const Text('Créer un compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = ZScope.of(context);
      final result = await scope.api.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      final shouldClaim = scope.session.history.isNotEmpty;
      await scope.session.authenticate(result, api: scope.api);
      if (!mounted) return;
      if (shouldClaim) await _maybeClaimDeviceDrafts(context);
      if (!mounted) return;
      if (kDebugMode) debugPrint('Auth route after login: ${AppRoutes.home}');
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } catch (error) {
      if (mounted) {
        if (error is ApiException && error.code == 'EMAIL_NOT_VERIFIED') {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.verifyEmail,
            arguments: error.email ?? _email.text.trim(),
          );
          return;
        }
        setState(() => _error = _authErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Bon retour',
      subtitle: 'Connectez-vous pour reprendre vos brouillons.',
      error: _error,
      children: [
        ZTextField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        ZTextField(
          controller: _password,
          label: 'Mot de passe',
          obscureText: true,
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Connexion...' : 'Se connecter'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.register),
          child: const Text('Créer un compte'),
        ),
      ],
    );
  }
}

String _authErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  final message = error.toString().replaceFirst('Bad state: ', '').trim();
  return message.isEmpty ? 'Erreur inattendue. Réessayez.' : message;
}

Future<void> _maybeClaimDeviceDrafts(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Associer les brouillons ?'),
      content: const Text(
        'Associer les brouillons de cet appareil à votre compte ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Associer'),
        ),
      ],
    ),
  );
  if (!context.mounted || !(confirmed ?? false)) return;
  final scope = ZScope.of(context);
  try {
    await scope.session.claimDeviceDrafts(scope.api);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_authErrorMessage(error))));
  }
}

Future<bool> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Se déconnecter ?'),
      content: const Text('Votre session sera supprimée de cet appareil.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Se déconnecter'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_password.text != _confirmPassword.text) {
        throw const ApiException('Les mots de passe ne correspondent pas.');
      }
      final scope = ZScope.of(context);
      final result = await scope.api.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.verifyEmail,
        arguments: result.email.isEmpty ? _email.text.trim() : result.email,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _authErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Créer un compte',
      subtitle: 'Préparez vos e-mails vocaux en quelques secondes.',
      error: _error,
      children: [
        ZTextField(controller: _name, label: 'Nom'),
        ZTextField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        ZTextField(
          controller: _password,
          label: 'Mot de passe',
          obscureText: true,
        ),
        ZTextField(
          controller: _confirmPassword,
          label: 'Confirmer le mot de passe',
          obscureText: true,
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Création...' : 'Créer mon compte'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.login),
          child: const Text('J’ai déjà un compte'),
        ),
      ],
    );
  }
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  Timer? _timer;
  int _resendSeconds = 60;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = widget.email;
    _code.addListener(() => setState(() {}));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _resendSeconds == 0) return;
      setState(() => _resendSeconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final scope = ZScope.of(context);
      final shouldClaim = scope.session.history.isNotEmpty;
      final result = await scope.api.verifyEmail(
        email: _email.text.trim(),
        code: _code.text.trim(),
      );
      await scope.session.authenticate(result, api: scope.api);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail vérifié avec succès.')),
      );
      if (shouldClaim) await _maybeClaimDeviceDrafts(context);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } catch (error) {
      if (mounted) setState(() => _error = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSeconds > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ZScope.of(
        context,
      ).api.resendVerificationCode(email: _email.text.trim());
      if (!mounted) return;
      setState(() => _resendSeconds = 60);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code renvoyé.')));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Impossible d’envoyer le code. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Vérifiez votre e-mail',
      subtitle: 'Entrez le code à 6 chiffres envoyé à votre adresse.',
      error: _error,
      children: [
        ZTextField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Code de vérification',
            counterText: '',
          ),
        ),
        FilledButton(
          onPressed: _verifying || _code.text.trim().length != 6
              ? null
              : _verify,
          child: Text(_verifying ? 'Vérification...' : 'Vérifier'),
        ),
        TextButton(
          onPressed: _resendSeconds > 0 || _resending ? null : _resend,
          child: Text(
            _resendSeconds > 0
                ? 'Renvoyer dans ${_resendSeconds}s'
                : _resending
                ? 'Envoi...'
                : 'Renvoyer le code',
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scope = ZScope.of(context);
      unawaited(scope.session.refreshHistory(scope.api));
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ZScope.of(context).session;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return ZScaffold(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    const ZLogo(size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour, ${session.user?.name ?? 'Z'}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Parlez. Z rédige.',
                            style: TextStyle(
                              color: ZTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.settings),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.profile),
                      icon: CircleAvatar(
                        backgroundColor: ZTheme.accentOf(context),
                        foregroundColor: Colors.white,
                        child: Text(_initials(session.user?.name)),
                      ),
                    ),
                  ],
                ),
                if (session.offlineHistory) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Hors ligne — données locales affichées',
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.voiceRecord,
                    arguments: const VoiceRecordArgs(autoStart: true),
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Commencer'),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: SectionTitle(title: 'E-mails récents'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.history),
                      child: const Text('Tout voir'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (session.history.isEmpty)
                  const EmptyStateCard()
                else
                  for (final draft
                      in session.history
                          .where(
                            (draft) => draft.status != EmailDraftStatus.deleted,
                          )
                          .take(3))
                    EmailCard(
                      draft: draft,
                      onDelete: () => _confirmDelete(context, draft),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, EmailDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet e-mail ?'),
        content: Text(draft.subject),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (context.mounted && (confirmed ?? false)) {
      final scope = ZScope.of(context);
      scope.session.markDraftDeleted(draft.id);
      unawaited(
        scope.api.deleteDraft(
          token: scope.session.accessToken,
          deviceId: scope.session.deviceId,
          draftId: draft.id,
        ),
      );
    }
  }

  String _initials(String? name) {
    final parts = (name ?? 'Z').trim().split(RegExp(r'\s+'));
    return parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }
}

class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({super.key, required this.autoStart});

  final bool autoStart;

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final _manualTranscript = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  VoiceRecordState _state = VoiceRecordState.idle;
  int _seconds = 0;
  Timer? _timer;
  String? _error;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_recorder.dispose());
    _pulse.dispose();
    _manualTranscript.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final session = ZScope.of(context).session;
    final permitted = await _requestMicrophonePermission();
    if (!permitted) {
      setState(() {
        _state = VoiceRecordState.error;
        _error = 'Autorisez le microphone pour dicter votre e-mail.';
      });
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/z_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _debugLog('VoiceRecord audio file path: $path');

    setState(() {
      _state = VoiceRecordState.recording;
      _error = null;
      _seconds = 0;
      _recordingPath = path;
      _manualTranscript.clear();
    });
    session.setTranscript('');
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds += 1);
    });

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
      path: path,
    );
  }

  Future<bool> _requestMicrophonePermission() async {
    return _recorder.hasPermission();
  }

  Future<void> _finishRecording() async {
    final scope = ZScope.of(context);
    final session = ZScope.of(context).session;
    _timer?.cancel();
    try {
      final stoppedPath = await _recorder.stop();
      if (!mounted) return;
      final path = stoppedPath ?? _recordingPath;
      if (path == null) throw StateError('Aucun fichier audio à transcrire.');

      final audioFile = File(path);
      final size = await audioFile.length();
      _debugLog('VoiceRecord audio file size: $size');
      if (size == 0) throw StateError('Le fichier audio est vide. Réessayez.');

      setState(() => _state = VoiceRecordState.transcribing);
      final result = await scope.api.transcribeSpeech(
        audioFile,
        session.transcriptionLanguage,
      );
      if (!mounted) return;

      final transcript = result.transcript.trim();
      session.setTranscript(transcript);
      session.setLastDetectedSpeechLanguage(result.language);
      _manualTranscript.text = transcript;
      _manualTranscript.selection = TextSelection.collapsed(
        offset: transcript.length,
      );
      _debugLog(
        'VoiceRecord final transcript state length: ${transcript.length}',
      );

      setState(() {
        _state = transcript.isEmpty
            ? VoiceRecordState.empty
            : VoiceRecordState.completed;
        _error = transcript.isEmpty
            ? session.transcriptionLanguage.emptyTranscriptMessage
            : null;
      });

      if (transcript.isNotEmpty) {
        await _generateEmail();
      }
    } catch (error) {
      if (!mounted) return;
      session.setTranscript('');
      setState(() {
        _state = VoiceRecordState.error;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _generateEmail() async {
    final scope = ZScope.of(context);
    setState(() {
      _state = VoiceRecordState.understanding;
      _error = null;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      setState(() => _state = VoiceRecordState.generating);
      final email = await scope.api.generateEmail(
        transcript: scope.session.transcript,
        template: scope.session.selectedTemplate,
        language: scope.session.transcriptLanguageForGeneration,
        outputLanguage: scope.session.outputLanguageForGeneration,
      );
      scope.session.applyGeneratedEmail(email);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.emailPreview);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = VoiceRecordState.error;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowShell(
      title: 'Enregistrement vocal',
      step: '1/2',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final scale = _state == VoiceRecordState.recording
                    ? 1 + (_pulse.value * 0.12)
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: GestureDetector(
                onTap: _canRecordTap
                    ? (_state == VoiceRecordState.recording
                          ? _finishRecording
                          : _startRecording)
                    : null,
                child: Container(
                  width: 164,
                  height: 164,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _state == VoiceRecordState.recording
                        ? const Color(0xFFEF4444)
                        : ZTheme.accentOf(context),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_state == VoiceRecordState.recording
                                    ? const Color(0xFFEF4444)
                                    : ZTheme.accentOf(context))
                                .withValues(alpha: 0.32),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Icon(
                    _state == VoiceRecordState.recording
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    color: Colors.white,
                    size: 62,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _stateLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(_seconds),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Waveform(
            active:
                _state == VoiceRecordState.recording ||
                _state == VoiceRecordState.transcribing,
          ),
          const SizedBox(height: 24),
          if (_showTranscriptCard)
            ZTextField(
              controller: _manualTranscript,
              label: 'Transcript',
              minLines: 4,
              maxLines: 7,
            ),
          if (_state == VoiceRecordState.transcribing ||
              _state == VoiceRecordState.understanding ||
              _state == VoiceRecordState.generating) ...[
            const SizedBox(height: 16),
            const EmailSkeletonLoader(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_state == VoiceRecordState.empty ||
              _state == VoiceRecordState.error) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _startRecording,
              child: const Text('Réenregistrer'),
            ),
          ],
          const Spacer(),
          if (_state == VoiceRecordState.recording)
            FilledButton.icon(
              onPressed: _finishRecording,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Terminer'),
            )
          else
            OutlinedButton(
              onPressed: _canRecordTap ? _startRecording : null,
              child: const Text('Recommencer'),
            ),
        ],
      ),
    );
  }

  String get _stateLabel {
    return switch (_state) {
      VoiceRecordState.idle => 'Appuyez pour parler',
      VoiceRecordState.recording => 'Enregistrement...',
      VoiceRecordState.transcribing => 'Transcription...',
      VoiceRecordState.understanding => 'Compréhension...',
      VoiceRecordState.generating => 'Rédaction...',
      VoiceRecordState.completed => 'Transcription prête',
      VoiceRecordState.empty => 'Aucun texte détecté',
      VoiceRecordState.error => 'Transcription impossible',
    };
  }

  bool get _canRecordTap {
    return _state == VoiceRecordState.idle ||
        _state == VoiceRecordState.recording ||
        _state == VoiceRecordState.completed ||
        _state == VoiceRecordState.empty ||
        _state == VoiceRecordState.error;
  }

  bool get _showTranscriptCard {
    return _state == VoiceRecordState.completed &&
        _manualTranscript.text.trim().isNotEmpty;
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
}

class EmailPreviewScreen extends StatefulWidget {
  const EmailPreviewScreen({super.key});

  @override
  State<EmailPreviewScreen> createState() => _EmailPreviewScreenState();
}

class _EmailPreviewScreenState extends State<EmailPreviewScreen> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static const _mailLauncher = MailLauncherService();

  late final TextEditingController _recipient;
  late final TextEditingController _subject;
  late final TextEditingController _body;
  final _customTone = TextEditingController();
  EmailTone _selectedTone = EmailTone.professional;
  bool _initialized = false;
  bool _saving = false;
  bool _openingMail = false;
  bool _regenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recipient = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final email = ZScope.of(context).session.generatedEmail;
    _selectedTone = email?.tone ?? EmailTone.professional;
    _recipient.text = email?.suggestedRecipient ?? '';
    _subject = TextEditingController(text: email?.subject ?? '');
    _body = TextEditingController(text: email?.body ?? '');
  }

  @override
  void dispose() {
    _recipient.dispose();
    _subject.dispose();
    _body.dispose();
    _customTone.dispose();
    super.dispose();
  }

  Future<EmailDraft?> _persistDraft({required bool showSnackBar}) async {
    final scope = ZScope.of(context);
    final localDraft = EmailDraft(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      subject: _subject.text,
      body: _body.text,
      tone: scope.session.tone,
      status: EmailDraftStatus.draft,
      createdAt: DateTime.now(),
    );

    EmailDraft draft = localDraft;
    try {
      draft = await scope.api.saveDraft(
        token: scope.session.accessToken,
        deviceId: scope.session.deviceId,
        recipient: _recipient.text,
        subject: _subject.text,
        body: _body.text,
        tone: scope.session.tone,
        transcript: scope.session.transcript,
        templateKey: scope.session.selectedTemplate,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Draft saved locally after API failure: $error');
      }
    }
    scope.session.addDraft(draft);
    if (mounted && showSnackBar) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Brouillon sauvegardé')));
    }
    return draft;
  }

  Future<void> _saveDraft() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _persistDraft(showSnackBar: true);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() {
      _regenerating = true;
      _error = null;
    });
    try {
      final scope = ZScope.of(context);
      final email = await scope.api.generateEmail(
        transcript: scope.session.transcript,
        tone: _selectedTone.apiValue,
        customTone: _selectedTone == EmailTone.custom ? _customTone.text : null,
        template: scope.session.selectedTemplate,
        language: scope.session.transcriptLanguageForGeneration,
        outputLanguage: scope.session.outputLanguageForGeneration,
      );
      scope.session.applyGeneratedEmail(email);
      if (_selectedTone != EmailTone.custom) _selectedTone = email.tone;
      _subject.text = email.subject;
      _body.text = email.body;
      if (_recipient.text.trim().isEmpty &&
          email.suggestedRecipient.trim().isNotEmpty) {
        _recipient.text = email.suggestedRecipient;
      }
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _openMail() async {
    final scope = ZScope.of(context);
    final session = scope.session;
    final api = scope.api;
    final recipient = _recipient.text.trim();
    final subject = _subject.text.trim();
    final body = _body.text;

    if (subject.isEmpty || body.trim().isEmpty) {
      setState(() => _error = 'Objet et message sont obligatoires.');
      return;
    }

    if (recipient.isNotEmpty && !_emailPattern.hasMatch(recipient)) {
      setState(() => _error = 'Adresse e-mail invalide.');
      return;
    }

    if (recipient.isEmpty) {
      final shouldContinue = await _showMissingRecipientDialog();
      if (!shouldContinue || !mounted) return;
    }

    setState(() {
      _openingMail = true;
      _error = null;
    });

    EmailDraft? draft;
    try {
      draft = await _persistDraft(showSnackBar: false);
      final launched = await _mailLauncher.openEmailComposer(
        preferredAppCode: session.preferredMailApp.code,
        recipientEmail: recipient.isEmpty ? null : recipient,
        subject: subject,
        body: body,
      );

      if (!mounted) return;
      if (!launched) {
        await _showMailFallbackDialog(
          recipientEmail: recipient,
          subject: subject,
          body: body,
        );
        return;
      }

      if (draft != null && draft.id.startsWith('local-')) {
        session.updateDraftStatus(draft.id, EmailDraftStatus.openedInMailApp);
      } else if (draft != null && draft.id.isNotEmpty) {
        try {
          await api.markDraftOpenedInMailApp(
            token: session.accessToken,
            deviceId: session.deviceId,
            draftId: draft.id,
          );
          session.updateDraftStatus(draft.id, EmailDraftStatus.openedInMailApp);
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Draft status update failed: $error');
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-mail ouvert dans votre application mail.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _openingMail = false);
    }
  }

  Future<bool> _showMissingRecipientDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aucun destinataire'),
          content: const Text(
            'Aucun destinataire saisi. Vous pourrez l’ajouter dans votre application mail.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showMailFallbackDialog({
    required String recipientEmail,
    required String subject,
    required String body,
  }) {
    final all = [
      'To: $recipientEmail',
      '',
      'Subject: $subject',
      '',
      body,
    ].join('\n');

    Future<void> copy(String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contenu copié.')));
    }

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aucune application mail trouvée'),
          content: const Text(
            'Copiez le contenu et collez-le dans Gmail, Outlook, Proton Mail ou Apple Mail.',
          ),
          actions: [
            TextButton(
              onPressed: () => copy(all),
              child: const Text('Copier tout'),
            ),
            TextButton(
              onPressed: () => copy(subject),
              child: const Text('Copier l’objet'),
            ),
            TextButton(
              onPressed: () => copy(body),
              child: const Text('Copier le message'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ZScope.of(context).session;
    final email = session.generatedEmail;
    final emailLanguage = email?.language ?? session.emailOutputLanguage.code;
    final isArabicEmail =
        SpeechLanguage.fromCode(emailLanguage) == SpeechLanguage.ar;
    return FlowShell(
      title: 'Prévisualisation',
      step: '2/2',
      child: ListView(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(
                icon: Icons.language_rounded,
                label: _languageLabel(session, email?.language ?? ''),
              ),
              InfoPill(
                icon: Icons.psychology_alt_outlined,
                label: email?.intent.trim().isEmpty ?? true
                    ? 'Intention détectée'
                    : email!.intent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToneSelector(
            selected: _selectedTone,
            onChanged: (tone) {
              setState(() {
                _selectedTone = tone;
                ZScope.of(context).session.setTone(tone.apiValue);
              });
              if (tone != EmailTone.custom) unawaited(_regenerate());
            },
          ),
          if (_selectedTone == EmailTone.custom) ...[
            const SizedBox(height: 10),
            ZTextField(
              controller: _customTone,
              label: 'Décrivez le ton souhaité',
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _regenerating ? null : _regenerate,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Confirmer le ton'),
            ),
          ] else if (_regenerating) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDecoration(),
              child: const Text(
                'Régénération avec le ton sélectionné...',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ZTextField(controller: _recipient, label: 'Destinataire'),
          const SizedBox(height: 12),
          ZTextField(
            controller: _subject,
            label: 'Objet',
            textDirection: isArabicEmail
                ? TextDirection.rtl
                : TextDirection.ltr,
            textAlign: isArabicEmail ? TextAlign.right : TextAlign.start,
          ),
          const SizedBox(height: 12),
          ZTextField(
            controller: _body,
            label: 'Message',
            minLines: 10,
            maxLines: 16,
            textDirection: isArabicEmail
                ? TextDirection.rtl
                : TextDirection.ltr,
            textAlign: isArabicEmail ? TextAlign.right : TextAlign.start,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openingMail ? null : _openMail,
            icon: const Icon(Icons.send_rounded),
            label: Text(_openingMail ? 'Ouverture...' : 'Envoyer'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Sauvegarde...' : 'Sauvegarder'),
          ),
          const SizedBox(height: 6),
          Text(
            'Application mail : ${ZScope.of(context).session.preferredMailApp.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
            icon: const Icon(Icons.history_rounded),
            label: const Text('History'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
            child: const Text('Retour à l’accueil'),
          ),
        ],
      ),
    );
  }

  String _languageLabel(AppSession session, String emailLanguage) {
    final outputLanguage = SpeechLanguage.fromCode(emailLanguage);
    if (outputLanguage != SpeechLanguage.auto) {
      return 'Email: ${outputLanguage.label}';
    }

    final detected = session.lastDetectedSpeechLanguage.toLowerCase();
    if (detected == 'unknown' || detected.trim().isEmpty) {
      return 'Email: Auto';
    }
    return 'Email: ${SpeechLanguage.fromCode(detected).label}';
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  HistorySort _sort = HistorySort.recent;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scope = ZScope.of(context);
      unawaited(scope.session.refreshHistory(scope.api));
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ZScope.of(context).session;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final drafts = _visibleDrafts(session.history);
        return FlowShell(
          title: 'Mes Emails',
          step: '',
          child: ListView(
            children: [
              ZTextField(controller: _search, label: 'Search'),
              if (session.offlineHistory) ...[
                const SizedBox(height: 10),
                const Text(
                  'Hors ligne — données locales affichées',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sort in HistorySort.values)
                    ChoiceChip(
                      label: Text(sort.label),
                      selected: _sort == sort,
                      onSelected: (_) => setState(() => _sort = sort),
                      selectedColor: ZTheme.blue.withValues(alpha: 0.12),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: drafts.isEmpty
                      ? null
                      : () => _confirmClear(drafts),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Delete all'),
                ),
              ),
              if (drafts.isEmpty)
                const EmptyStateCard()
              else
                for (final draft in drafts)
                  EmailCard(
                    draft: draft,
                    onDelete: draft.status == EmailDraftStatus.deleted
                        ? null
                        : () => _confirmDelete(draft),
                    onRestore: draft.status == EmailDraftStatus.deleted
                        ? () => _updateStatus(draft, EmailDraftStatus.draft)
                        : null,
                    onDuplicate: () => _duplicateDraft(draft),
                    onOpen: () {
                      session.openDraftInPreview(draft);
                      Navigator.of(context).pushNamed(AppRoutes.emailPreview);
                    },
                  ),
            ],
          ),
        );
      },
    );
  }

  List<EmailDraft> _visibleDrafts(List<EmailDraft> source) {
    final query = _search.text.trim().toLowerCase();
    final filtered = source.where((draft) {
      final matchesQuery =
          query.isEmpty ||
          draft.subject.toLowerCase().contains(query) ||
          draft.body.toLowerCase().contains(query);
      final matchesSort = switch (_sort) {
        HistorySort.recent => true,
        HistorySort.oldest => draft.status == EmailDraftStatus.scheduled,
        HistorySort.drafts => draft.status == EmailDraftStatus.draft,
        HistorySort.sent => draft.status == EmailDraftStatus.openedInMailApp,
        HistorySort.deleted => draft.status == EmailDraftStatus.deleted,
      };
      return matchesQuery && matchesSort;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<void> _confirmDelete(EmailDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this email?'),
        content: Text(draft.subject),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (mounted && (confirmed ?? false)) {
      await _updateStatus(draft, EmailDraftStatus.deleted);
    }
  }

  Future<void> _confirmClear(List<EmailDraft> drafts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all visible emails?'),
        content: const Text(
          'Deleted emails can be restored from the Deleted sort.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (!mounted || !(confirmed ?? false)) return;
    for (final draft in drafts) {
      await _updateStatus(draft, EmailDraftStatus.deleted);
    }
  }

  Future<void> _updateStatus(EmailDraft draft, EmailDraftStatus status) async {
    final scope = ZScope.of(context);
    scope.session.updateDraftStatus(draft.id, status);
    try {
      await scope.api.updateDraftStatus(
        token: scope.session.accessToken,
        deviceId: scope.session.deviceId,
        draftId: draft.id,
        status: status,
      );
    } catch (_) {
      scope.session.markOfflineHistory();
    }
  }

  Future<void> _duplicateDraft(EmailDraft draft) async {
    final scope = ZScope.of(context);
    try {
      final duplicated = await scope.api.duplicateDraft(
        token: scope.session.accessToken,
        deviceId: scope.session.deviceId,
        draftId: draft.id,
      );
      scope.session.addDraft(duplicated);
    } catch (_) {
      scope.session.duplicateDraft(draft);
      scope.session.markOfflineHistory();
    }
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _name.text = ZScope.of(context).session.user?.name ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final scope = ZScope.of(context);
      final token = scope.session.accessToken;
      if (token == null) throw const ApiException('Session expirée.');
      final user = await scope.api.updateMe(token: token, name: _name.text);
      await scope.session.updateUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
    } catch (error) {
      if (mounted) setState(() => _error = _authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await _confirmLogout(context);
    if (!mounted || !confirmed) return;
    final scope = ZScope.of(context);
    await scope.session.logout(scope.api);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ZScope.of(context).session;
    final user = session.user;
    return FlowShell(
      title: 'Profil',
      step: '',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: ZTheme.accentOf(context),
                  foregroundColor: Colors.white,
                  child: Text(
                    _initials(user?.name),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Utilisateur',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ZTheme.muted),
                ),
                const SizedBox(height: 18),
                ZTextField(controller: _name, label: 'Nom'),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveName,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Sauvegarde...' : 'Enregistrer'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Préférences'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Mes Emails'),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? 'Z').trim().split(RegExp(r'\s+'));
    return parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = ZScope.of(context).session;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return FlowShell(
          title: 'Réglages',
          step: '',
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: ZTheme.accentOf(context),
                      foregroundColor: Colors.white,
                      child: Text(_initials(session.user?.name)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.user?.name ?? 'Utilisateur',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            session.user?.email ?? '',
                            style: const TextStyle(color: ZTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profil',
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.profile),
                      icon: const Icon(Icons.person_outline_rounded),
                    ),
                    IconButton(
                      tooltip: 'Déconnexion',
                      onPressed: () async {
                        final confirmed = await _confirmLogout(context);
                        if (!context.mounted || !confirmed) return;
                        final scope = ZScope.of(context);
                        await scope.session.logout(scope.api);
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.login,
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apparence',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final mode in ThemeMode.values)
                          ChoiceChip(
                            label: Text(_themeModeLabel(mode)),
                            selected: session.themeMode == mode,
                            onSelected: (_) => session.setThemeMode(mode),
                            selectedColor: ZTheme.accentOf(
                              context,
                            ).withValues(alpha: 0.14),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Couleur accent',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final accent in ZAccentColor.values)
                          ChoiceChip(
                            avatar: CircleAvatar(
                              radius: 8,
                              backgroundColor: accent.color,
                            ),
                            label: Text(accent.label),
                            selected: session.accentColor == accent,
                            onSelected: (_) => session.setAccentColor(accent),
                            selectedColor: accent.color.withValues(alpha: 0.14),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speech language',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Language spoken in the recording',
                      style: TextStyle(
                        color: ZTheme.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LanguageSelector(
                      selected: session.transcriptionLanguage,
                      onChanged: session.setTranscriptionLanguage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email language',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Language of the generated email',
                      style: TextStyle(
                        color: ZTheme.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LanguageSelector(
                      selected: session.emailOutputLanguage,
                      onChanged: session.setEmailOutputLanguage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Application mail préférée',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Set<String>>(
                      future: const MailLauncherService()
                          .detectAvailableProviderCodes(),
                      builder: (context, snapshot) {
                        final detected = snapshot.data;
                        final apps = PreferredMailApp.values.where((app) {
                          if (app == PreferredMailApp.appleMail) return false;
                          return detected == null ||
                              detected.contains(app.code) ||
                              app == PreferredMailApp.protonMail;
                        });
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final app in apps)
                              ChoiceChip(
                                label: Text(app.label),
                                selected: session.preferredMailApp == app,
                                onSelected: (_) =>
                                    session.setPreferredMailApp(app),
                                selectedColor: ZTheme.accentOf(
                                  context,
                                ).withValues(alpha: 0.12),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Z utilise les applications mail disponibles sur votre téléphone. Si l’application choisie n’est pas disponible, Z utilisera l’application par défaut ou copiera l’e-mail.',
                      style: TextStyle(
                        color: ZTheme.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoPill(
                      icon: Icons.graphic_eq_rounded,
                      label: 'Speech: Deepgram',
                    ),
                    SizedBox(height: 8),
                    InfoPill(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Generation: Groq',
                    ),
                    SizedBox(height: 8),
                    InfoPill(
                      icon: Icons.info_outline_rounded,
                      label: 'Version: Z 1.0',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  String _initials(String? name) {
    final parts = (name ?? 'Z').trim().split(RegExp(r'\s+'));
    return parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final SpeechLanguage selected;
  final ValueChanged<SpeechLanguage> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final language in SpeechLanguage.values)
          ChoiceChip(
            label: Text(language.label),
            selected: selected == language,
            onSelected: enabled ? (_) => onChanged(language) : null,
            selectedColor: ZTheme.accentOf(context).withValues(alpha: 0.12),
            backgroundColor: ZTheme.card,
            labelStyle: TextStyle(
              color: selected == language
                  ? ZTheme.accentOf(context)
                  : ZTheme.ink,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
      ],
    );
  }
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.error,
  });

  final String title;
  final String subtitle;
  final String? error;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ZScaffold(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            const Center(child: ZLogo(size: 64)),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: ZTheme.muted),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children.expand(
                    (child) => [child, const SizedBox(height: 12)],
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlowShell extends StatelessWidget {
  const FlowShell({
    super.key,
    required this.title,
    required this.step,
    required this.child,
  });

  final String title;
  final String step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ZScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (step.isNotEmpty)
                    Text(
                      step,
                      style: const TextStyle(
                        color: ZTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class ZScaffold extends StatelessWidget {
  const ZScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}

class ZLogo extends StatelessWidget {
  const ZLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/z_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class ZTextField extends StatelessWidget {
  const ZTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.textDirection,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final TextDirection? textDirection;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      textDirection: textDirection,
      textAlign: textAlign,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ZTheme.ink,
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mail_outline_rounded, color: ZTheme.blue),
          SizedBox(height: 10),
          Text(
            'Aucun e-mail récent',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Vos brouillons sauvegardés apparaîtront ici.',
            style: TextStyle(color: ZTheme.muted),
          ),
        ],
      ),
    );
  }
}

class EmailCard extends StatelessWidget {
  const EmailCard({
    super.key,
    required this.draft,
    this.onDelete,
    this.onRestore,
    this.onDuplicate,
    this.onOpen,
  });

  final EmailDraft draft;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onDuplicate;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.subject,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            draft.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ZTheme.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              if (onOpen != null)
                TextButton(onPressed: onOpen, child: const Text('Open')),
              if (onDuplicate != null)
                TextButton(
                  onPressed: onDuplicate,
                  child: const Text('Duplicate'),
                ),
              if (onRestore != null)
                TextButton(onPressed: onRestore, child: const Text('Restore')),
            ],
          ),
        ],
      ),
    );
  }
}

class ToneSelector extends StatelessWidget {
  const ToneSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final EmailTone selected;
  final ValueChanged<EmailTone> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Ton détecté',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: ZTheme.muted),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tone in EmailTone.values)
                ChoiceChip(
                  label: Text(tone.label),
                  selected: selected == tone,
                  onSelected: (_) => onChanged(tone),
                  selectedColor: ZTheme.blue.withValues(alpha: 0.12),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ZTheme.blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class EmailSkeletonLoader extends StatelessWidget {
  const EmailSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(widthFactor: 0.55),
          SizedBox(height: 10),
          SkeletonLine(widthFactor: 0.92),
          SizedBox(height: 8),
          SkeletonLine(widthFactor: 0.78),
        ],
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EEF8),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: CustomPaint(painter: WaveformPainter(active: active)),
    );
  }
}

class WaveformPainter extends CustomPainter {
  const WaveformPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = active ? ZTheme.blue : const Color(0xFFCBD5E1);
    final center = size.height / 2;
    for (var i = 0; i < 28; i++) {
      final x = (size.width / 27) * i;
      final amp = active ? 12 + (math.sin(i * 0.85) * 16).abs() : 8;
      canvas.drawLine(Offset(x, center - amp), Offset(x, center + amp), paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.active != active;
}

BoxDecoration cardDecoration({
  Color color = Colors.white,
  Color borderColor = const Color(0xFFE2E8F0),
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  );
}
