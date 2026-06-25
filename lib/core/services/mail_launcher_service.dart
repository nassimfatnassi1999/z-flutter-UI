import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class MailProvider {
  Future<bool> send({
    required String preferredAppCode,
    required String subject,
    required String body,
    String? recipientEmail,
  });

  Future<Set<String>> detectAvailableProviderCodes();
}

class MailLauncherService {
  const MailLauncherService({this.provider = const NativeMailProvider()});

  final MailProvider provider;

  Future<bool> openEmailComposer({
    required String preferredAppCode,
    required String subject,
    required String body,
    String? recipientEmail,
  }) async {
    return provider.send(
      preferredAppCode: preferredAppCode,
      subject: subject,
      body: body,
      recipientEmail: recipientEmail,
    );
  }

  Future<Set<String>> detectAvailableProviderCodes() {
    return provider.detectAvailableProviderCodes();
  }
}

class NativeMailProvider implements MailProvider {
  const NativeMailProvider();

  @override
  Future<Set<String>> detectAvailableProviderCodes() async {
    final detected = <String>{'system', 'copy_only'};
    final checks = {
      'gmail': Uri(scheme: 'googlegmail'),
      'outlook': Uri(scheme: 'ms-outlook'),
      'apple_mail': _mailtoUri(null, '', ''),
    };

    for (final entry in checks.entries) {
      final available = await canLaunchUrl(entry.value);
      _debugLog(
        'MailProvider detect provider=${entry.key} scheme=${entry.value.scheme} canLaunch=$available',
      );
      if (available) detected.add(entry.key);
    }

    return detected;
  }

  @override
  Future<bool> send({
    required String preferredAppCode,
    required String subject,
    required String body,
    String? recipientEmail,
  }) async {
    _debugLog('MailProvider selected=$preferredAppCode');
    if (preferredAppCode == 'copy_only') {
      _debugLog('MailProvider fallback=copy_only');
      return false;
    }

    final preferredUri = _preferredUri(
      preferredAppCode,
      recipientEmail: recipientEmail,
      subject: subject,
      body: body,
    );
    if (preferredUri != null && await _tryLaunch(preferredUri)) {
      return true;
    }

    final launched = await _tryLaunch(
      _mailtoUri(recipientEmail, subject, body),
    );
    if (!launched) _debugLog('MailProvider fallback=copy_dialog');
    return launched;
  }

  Uri _mailtoUri(String? recipientEmail, String subject, String body) {
    return Uri(
      scheme: 'mailto',
      path: recipientEmail?.trim() ?? '',
      queryParameters: _composerParams(subject: subject, body: body),
    );
  }

  Uri? _preferredUri(
    String preferredAppCode, {
    required String? recipientEmail,
    required String subject,
    required String body,
  }) {
    final to = recipientEmail?.trim() ?? '';
    return switch (preferredAppCode) {
      'gmail' => Uri(
        scheme: 'googlegmail',
        host: 'co',
        queryParameters: _composerParams(to: to, subject: subject, body: body),
      ),
      'outlook' => Uri(
        scheme: 'ms-outlook',
        host: 'compose',
        queryParameters: _composerParams(to: to, subject: subject, body: body),
      ),
      _ => null,
    };
  }

  Map<String, String> _composerParams({
    String? to,
    required String subject,
    required String body,
  }) {
    return {?to: to, 'subject': subject, 'body': body};
  }

  Future<bool> _tryLaunch(Uri uri) async {
    final canLaunch = await canLaunchUrl(uri);
    _debugLog('MailProvider uriScheme=${uri.scheme} canLaunch=$canLaunch');
    if (!canLaunch) {
      return false;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    _debugLog('MailProvider uriScheme=${uri.scheme} launchResult=$launched');
    return launched;
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
