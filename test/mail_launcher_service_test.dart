import 'package:flutter_test/flutter_test.dart';
import 'package:z_mobile/core/services/mail_launcher_service.dart';

void main() {
  const provider = NativeMailProvider();

  test('mailto composer encodes spaces as percent escapes', () {
    final uri = provider.buildMailtoUri(
      'ashraf@example.com',
      'Application Creation',
      'Hello Ashraf,\n\n'
          'I wanted to let you know that I have created the application.\n\n'
          'Best regards,',
    );

    expect(uri.toString(), isNot(contains('+')));
    expect(uri.toString(), contains('Application%20Creation'));
    expect(uri.toString(), contains('Hello%20Ashraf%2C%0A%0A'));
    expect(uri.toString(), contains('Best%20regards%2C'));
  });

  test(
    'mailto composer preserves French, Arabic, punctuation, and long bodies',
    () {
      final longBody = [
        'Bonjour Élodie, ça va ?',
        'مرحبا أشرف، تم إنشاء التطبيق.',
        'Punctuation: ? & = # % + /',
        'Long body ${'message '.padRight(600, 'x')}',
      ].join('\n');
      final uri = provider.buildMailtoUri(
        'elodie@example.com',
        'Création تطبيق',
        longBody,
      );
      final value = uri.toString();

      expect(value, isNot(contains('+')));
      expect(value, contains('Cr%C3%A9ation%20%D8%AA%D8%B7%D8%A8%D9%8A%D9%82'));
      expect(value, contains('Bonjour%20%C3%89lodie%2C%20%C3%A7a%20va%20%3F'));
      expect(value, contains('%D9%85%D8%B1%D8%AD%D8%A8%D8%A7'));
      expect(
        value,
        contains('Punctuation%3A%20%3F%20%26%20%3D%20%23%20%25%20%2B%20%2F'),
      );
      expect(value, contains('%0A'));
    },
  );

  test('Gmail and Outlook composer links use the same safe encoding', () {
    final gmail = provider.buildPreferredUri(
      'gmail',
      recipientEmail: 'ashraf@example.com',
      subject: 'Hello Ashraf',
      body: 'Line one\nLine two',
    );
    final outlook = provider.buildPreferredUri(
      'outlook',
      recipientEmail: 'ashraf@example.com',
      subject: 'Bonjour Élodie',
      body: 'مرحبا أشرف',
    );

    expect(gmail.toString(), isNot(contains('+')));
    expect(gmail.toString(), contains('subject=Hello%20Ashraf'));
    expect(gmail.toString(), contains('body=Line%20one%0ALine%20two'));
    expect(outlook.toString(), isNot(contains('+')));
    expect(outlook.toString(), contains('Bonjour%20%C3%89lodie'));
    expect(outlook.toString(), contains('%D9%85%D8%B1%D8%AD%D8%A8%D8%A7'));
  });
}
