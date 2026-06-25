import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment from(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'staging' || 'stage' => AppEnvironment.staging,
      'production' || 'prod' || 'release' => AppEnvironment.production,
      _ => AppEnvironment.development,
    };
  }
}

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  final AppEnvironment environment;
  final String apiBaseUrl;

  String get apiV1 => '$apiBaseUrl/api/v1';

  static Future<AppConfig> load() async {
    final entries = await _loadEnvironmentEntries();
    final environment = AppEnvironment.from(
      _firstNonEmpty([
        const String.fromEnvironment('APP_ENV'),
        const String.fromEnvironment('ENVIRONMENT'),
        entries['APP_ENV'],
        entries['ENVIRONMENT'],
      ]),
    );
    final configuredApiBaseUrl = _firstNonEmpty([
      const String.fromEnvironment('API_BASE_URL'),
      entries['API_BASE_URL'],
      _environmentUrl(environment, entries),
    ]);
    final apiBaseUrl =
        configuredApiBaseUrl ?? _fallbackForEnvironment(environment, entries);

    return AppConfig(
      environment: environment,
      apiBaseUrl: _normalize(apiBaseUrl),
    );
  }

  static Future<Map<String, String>> _loadEnvironmentEntries() async {
    try {
      final raw = await rootBundle.loadString('.env');
      return Map.fromEntries(
        raw
            .split('\n')
            .map((line) => line.trim())
            .where(
              (line) =>
                  line.isNotEmpty &&
                  !line.startsWith('#') &&
                  line.contains('='),
            )
            .map((line) {
              final idx = line.indexOf('=');
              return MapEntry(
                line.substring(0, idx).trim(),
                line.substring(idx + 1).trim(),
              );
            }),
      );
    } catch (_) {
      return const {};
    }
  }

  static String? _environmentUrl(
    AppEnvironment environment,
    Map<String, String> entries,
  ) {
    return switch (environment) {
      AppEnvironment.development => entries['DEVELOPMENT_API_BASE_URL'],
      AppEnvironment.staging => entries['STAGING_API_BASE_URL'],
      AppEnvironment.production => entries['PRODUCTION_API_BASE_URL'],
    };
  }

  static String _fallbackForEnvironment(
    AppEnvironment environment,
    Map<String, String> entries,
  ) {
    if (environment == AppEnvironment.development) {
      return _developmentFallback(entries);
    }
    throw StateError('API_BASE_URL is required for ${environment.name}.');
  }

  static String _developmentFallback(Map<String, String> entries) {
    final port =
        _firstNonEmpty([
          const String.fromEnvironment('API_PORT'),
          entries['API_PORT'],
        ]) ??
        '3000';
    final lanIp = _firstNonEmpty([
      const String.fromEnvironment('API_LAN_IP'),
      entries['API_LAN_IP'],
    ]);

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$port';
    }

    if (!kIsWeb && Platform.isIOS) {
      if (_isIosSimulator) {
        return 'http://localhost:$port';
      }
      if (lanIp != null) {
        return 'http://$lanIp:$port';
      }
      throw StateError(
        'API_BASE_URL or API_LAN_IP is required for iOS physical devices.',
      );
    }

    return 'http://localhost:$port';
  }

  static bool get _isIosSimulator {
    if (kIsWeb || !Platform.isIOS) return false;
    return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
        Platform.environment.containsKey('SIMULATOR_UDID');
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    final withoutApi = trimmed.endsWith('/api/v1')
        ? trimmed.substring(0, trimmed.length - 7)
        : trimmed;
    return withoutApi.endsWith('/')
        ? withoutApi.substring(0, withoutApi.length - 1)
        : withoutApi;
  }
}
