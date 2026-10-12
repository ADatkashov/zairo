import 'package:business_admin/features/auth/data/auth_api.dart';
import 'package:business_admin/features/auth/data/auth_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

const _userJson = {
  'id': 'u1',
  'email': 'owner@example.com',
  'displayName': 'Aigerim',
  'role': 'PROVIDER_OWNER',
};

const _tokensJson = {'accessToken': 'access-1', 'refreshToken': 'refresh-1', 'user': _userJson};

Future<AuthErrorKey> _errorKey(Future<Object?> Function() call) async {
  try {
    await call();
  } on AuthException catch (e) {
    return e.key;
  }
  fail('expected an AuthException');
}

void main() {
  late FakeHttp http;
  late AuthApi api;

  setUp(() {
    http = FakeHttp();
    api = AuthApi(http.client());
  });

  group('accounts created in this app are business owners', () {
    test('register posts the form with the PROVIDER_OWNER role', () async {
      http.reply('POST', '/auth/register', _tokensJson);

      final tokens = await api.register(
        email: 'owner@example.com',
        password: 'password123',
        displayName: 'Aigerim',
        phone: '+77001234567',
      );

      expect(http.bodyOf('POST', '/auth/register'), {
        'email': 'owner@example.com',
        'password': 'password123',
        'displayName': 'Aigerim',
        'phone': '+77001234567',
        'role': 'PROVIDER_OWNER',
      });
      expect(tokens.user.role, 'PROVIDER_OWNER');
      expect(tokens.accessToken, 'access-1');
    });

    test('Google, Apple and phone sign-up all ask for the owner role', () async {
      http
        ..reply('POST', '/auth/google', _tokensJson)
        ..reply('POST', '/auth/apple', _tokensJson)
        ..reply('POST', '/auth/phone/register', _tokensJson);

      await api.loginWithGoogle('g-token');
      await api.loginWithApple('a-token', displayName: 'Aigerim');
      await api.registerWithPhone(phone: '+7700', code: '123456', displayName: 'Aigerim', password: 'secret123');

      expect(http.bodyOf('POST', '/auth/google'), {'idToken': 'g-token', 'role': 'PROVIDER_OWNER'});
      expect(http.bodyOf('POST', '/auth/apple'),
          {'identityToken': 'a-token', 'displayName': 'Aigerim', 'role': 'PROVIDER_OWNER'});
      expect(http.bodyOf('POST', '/auth/phone/register'), {
        'phone': '+7700',
        'code': '123456',
        'displayName': 'Aigerim',
        'password': 'secret123',
        'role': 'PROVIDER_OWNER',
      });
    });
  });

  group('email sign-in and password reset', () {
    test('register maps 409 to "email already registered" and rethrows anything else', () async {
      http.fail('POST', '/auth/register', 409);
      expect(
        await _errorKey(() => api.register(email: 'a@b.c', password: 'x', displayName: 'n', phone: 'p')),
        AuthErrorKey.emailAlreadyRegistered,
      );

      http.fail('POST', '/auth/register', 500);
      await expectLater(
        api.register(email: 'a@b.c', password: 'x', displayName: 'n', phone: 'p'),
        throwsA(isA<DioException>()),
      );
    });

    test('login posts the credentials and maps 401 to invalid credentials', () async {
      http.reply('POST', '/auth/login', _tokensJson);
      final tokens = await api.login(email: 'owner@example.com', password: 'secret123');
      expect(http.bodyOf('POST', '/auth/login'), {'email': 'owner@example.com', 'password': 'secret123'});
      expect(tokens.refreshToken, 'refresh-1');

      http.fail('POST', '/auth/login', 401);
      expect(await _errorKey(() => api.login(email: 'a@b.c', password: 'x')), AuthErrorKey.invalidCredentials);

      http.fail('POST', '/auth/login', 503);
      await expectLater(api.login(email: 'a@b.c', password: 'x'), throwsA(isA<DioException>()));
    });

    test('refresh exchanges the refresh token', () async {
      http.reply('POST', '/auth/refresh', _tokensJson);
      await api.refresh('refresh-0');
      expect(http.bodyOf('POST', '/auth/refresh'), {'refreshToken': 'refresh-0'});
    });

    test('forgotPassword and resetPassword post to their endpoints; 401 means a bad reset token', () async {
      http
        ..reply('POST', '/auth/forgot-password', <String, Object?>{})
        ..reply('POST', '/auth/reset-password', <String, Object?>{});

      await api.forgotPassword('owner@example.com');
      await api.resetPassword(token: 't', newPassword: 'newpass123');
      expect(http.bodyOf('POST', '/auth/forgot-password'), {'email': 'owner@example.com'});
      expect(http.bodyOf('POST', '/auth/reset-password'), {'token': 't', 'newPassword': 'newpass123'});

      http.fail('POST', '/auth/reset-password', 401);
      expect(await _errorKey(() => api.resetPassword(token: 't', newPassword: 'n')), AuthErrorKey.invalidResetToken);

      http.fail('POST', '/auth/reset-password', 500);
      await expectLater(api.resetPassword(token: 't', newPassword: 'n'), throwsA(isA<DioException>()));
    });

    test('resetPasswordWithPhone posts the code and maps OTP errors', () async {
      http.reply('POST', '/auth/phone/reset-password', <String, Object?>{});
      await api.resetPasswordWithPhone(phone: '+7700', code: '123456', newPassword: 'newpass123');
      expect(http.bodyOf('POST', '/auth/phone/reset-password'),
          {'phone': '+7700', 'code': '123456', 'newPassword': 'newpass123'});

      http.fail('POST', '/auth/phone/reset-password', 401, message: 'Code expired');
      expect(await _errorKey(() => api.resetPasswordWithPhone(phone: 'p', code: 'c', newPassword: 'n')),
          AuthErrorKey.otpExpired);
    });
  });

  group('session and profile', () {
    test('me sends the given access token explicitly', () async {
      http.reply('GET', '/auth/me', _userJson);
      final user = await api.me('token-xyz');
      expect(http.calls('GET', '/auth/me').single.headers['Authorization'], 'Bearer token-xyz');
      expect(user.email, 'owner@example.com');
    });

    test('updateAvatar patches the url, including null to remove it', () async {
      http.reply('PATCH', '/auth/me/avatar', _userJson);
      await api.updateAvatar('https://img/x.png');
      expect(http.bodyOf('PATCH', '/auth/me/avatar'), {'avatarUrl': 'https://img/x.png'});

      http.requests.clear();
      await api.updateAvatar(null);
      expect(http.bodyOf('PATCH', '/auth/me/avatar'), {'avatarUrl': null});
    });

    test('auditBiometricToggle reports whether biometrics were switched on', () async {
      http.reply('POST', '/auth/me/biometric-audit', <String, Object?>{});
      await api.auditBiometricToggle(false);
      expect(http.bodyOf('POST', '/auth/me/biometric-audit'), {'enabled': false});
    });

    test('listIdentities returns the linked providers', () async {
      http.reply('GET', '/auth/identities', {
        'identities': [
          {'provider': 'GOOGLE'},
          {'provider': 'PHONE'},
        ],
      });
      expect((await api.listIdentities()).map((i) => i.provider), ['GOOGLE', 'PHONE']);
    });
  });

  group('linking providers', () {
    test('linkGoogle, linkApple and linkPhone return the updated user', () async {
      http
        ..reply('POST', '/auth/identities/google', _userJson)
        ..reply('POST', '/auth/identities/apple', _userJson)
        ..reply('POST', '/auth/identities/phone/verify-otp', _userJson);

      expect((await api.linkGoogle('g')).id, 'u1');
      expect((await api.linkApple('a')).id, 'u1');
      expect((await api.linkPhone(phone: '+7700', code: '123456')).id, 'u1');

      expect(http.bodyOf('POST', '/auth/identities/google'), {'idToken': 'g'});
      expect(http.bodyOf('POST', '/auth/identities/apple'), {'identityToken': 'a'});
      expect(http.bodyOf('POST', '/auth/identities/phone/verify-otp'), {'phone': '+7700', 'code': '123456'});
    });

    test('provider errors: 401 invalid credential; 409 link-required vs already-registered; else invalid', () async {
      final paths = ['/auth/google', '/auth/apple', '/auth/identities/google', '/auth/identities/apple'];
      final calls = <Future<Object?> Function()>[
        () => api.loginWithGoogle('t'),
        () => api.loginWithApple('t'),
        () => api.linkGoogle('t'),
        () => api.linkApple('t'),
      ];
      for (final call in calls) {
        for (final path in paths) {
          http.fail('POST', path, 401);
        }
        expect(await _errorKey(call), AuthErrorKey.invalidProviderCredential);

        for (final path in paths) {
          http.fail('POST', path, 409, message: 'account_link_required');
        }
        expect(await _errorKey(call), AuthErrorKey.accountLinkRequired);

        for (final path in paths) {
          http.fail('POST', path, 409, message: 'Email taken');
        }
        expect(await _errorKey(call), AuthErrorKey.emailAlreadyRegistered);

        for (final path in paths) {
          http.fail('POST', path, 500);
        }
        expect(await _errorKey(call), AuthErrorKey.invalidProviderCredential);
      }
    });

    test('linkProviderWithPassword: 429 too many, 401 wrong password, 409 maps like a provider error', () async {
      http.reply('POST', '/auth/identities/link-with-password', _tokensJson);
      await api.linkProviderWithPassword(provider: 'GOOGLE', token: 't', password: 'secret123');
      expect(http.bodyOf('POST', '/auth/identities/link-with-password'),
          {'provider': 'GOOGLE', 'token': 't', 'password': 'secret123'});

      Future<Object?> call() => api.linkProviderWithPassword(provider: 'GOOGLE', token: 't', password: 'p');

      http.fail('POST', '/auth/identities/link-with-password', 429);
      expect(await _errorKey(call), AuthErrorKey.tooManyLoginAttempts);
      http.fail('POST', '/auth/identities/link-with-password', 401);
      expect(await _errorKey(call), AuthErrorKey.invalidCredentials);
      http.fail('POST', '/auth/identities/link-with-password', 409, message: 'x');
      expect(await _errorKey(call), AuthErrorKey.emailAlreadyRegistered);
    });
  });

  group('phone', () {
    test('requestPhoneOtp posts the phone and maps request errors', () async {
      http.reply('POST', '/auth/phone/request-otp', <String, Object?>{});
      await api.requestPhoneOtp('+7700');
      expect(http.bodyOf('POST', '/auth/phone/request-otp'), {'phone': '+7700'});

      Future<Object?> request() => api.requestPhoneOtp('+7700');
      http.fail('POST', '/auth/phone/request-otp', 400, message: 'Country not supported');
      expect(await _errorKey(request), AuthErrorKey.phoneCountryNotSupported);
      http.fail('POST', '/auth/phone/request-otp', 400, message: 'Bad number');
      expect(await _errorKey(request), AuthErrorKey.invalidPhoneNumber);
      http.fail('POST', '/auth/phone/request-otp', 429, message: 'Please wait 30 seconds');
      expect(await _errorKey(request), AuthErrorKey.otpResendCooldown);
      http.fail('POST', '/auth/phone/request-otp', 429, message: 'Daily limit reached');
      expect(await _errorKey(request), AuthErrorKey.tooManyOtpRequests);
      http.fail('POST', '/auth/phone/request-otp', 500);
      expect(await _errorKey(request), AuthErrorKey.invalidPhoneNumber);
    });

    test('linkPhone and registerWithPhone map OTP verification errors', () async {
      Future<Object?> link() => api.linkPhone(phone: 'p', code: 'c');

      http.fail('POST', '/auth/identities/phone/verify-otp', 401, message: 'Code has EXPIRED');
      expect(await _errorKey(link), AuthErrorKey.otpExpired);
      http.fail('POST', '/auth/identities/phone/verify-otp', 401, message: 'Wrong code');
      expect(await _errorKey(link), AuthErrorKey.invalidOtp);
      http.fail('POST', '/auth/identities/phone/verify-otp', 429);
      expect(await _errorKey(link), AuthErrorKey.tooManyOtpAttempts);
      http.fail('POST', '/auth/identities/phone/verify-otp', 409);
      expect(await _errorKey(link), AuthErrorKey.identityAlreadyLinked);
      http.fail('POST', '/auth/identities/phone/verify-otp', 500);
      expect(await _errorKey(link), AuthErrorKey.invalidOtp);

      http.fail('POST', '/auth/phone/register', 429);
      expect(
        await _errorKey(() => api.registerWithPhone(phone: 'p', code: 'c', displayName: 'n', password: 'w')),
        AuthErrorKey.tooManyOtpAttempts,
      );
    });

    test('smsMode reads the mock flag and code, defaulting to a real SMS', () async {
      http.reply('GET', '/auth/phone/sms-mode', {'mock': true, 'mockCode': '000000'});
      final mock = await api.smsMode();
      expect([mock.mock, mock.mockCode], [true, '000000']);

      http.reply('GET', '/auth/phone/sms-mode', <String, Object?>{});
      final real = await api.smsMode();
      expect([real.mock, real.mockCode], [false, null]);
    });

    test('phoneStatus tells whether the number is registered and has a password', () async {
      http.reply('POST', '/auth/phone/status', {'registered': true, 'hasPassword': true});
      final status = await api.phoneStatus('+7700');
      expect(http.bodyOf('POST', '/auth/phone/status'), {'phone': '+7700'});
      expect([status.registered, status.hasPassword], [true, true]);

      http.reply('POST', '/auth/phone/status', <String, Object?>{});
      final unknown = await api.phoneStatus('+7701');
      expect([unknown.registered, unknown.hasPassword], [false, false]);

      http.fail('POST', '/auth/phone/status', 400, message: 'not supported');
      expect(await _errorKey(() => api.phoneStatus('+1')), AuthErrorKey.phoneCountryNotSupported);
    });

    test('loginWithPhonePassword: 401 invalid, 429 too many, other errors pass through', () async {
      http.reply('POST', '/auth/phone/login', _tokensJson);
      await api.loginWithPhonePassword(phone: '+7700', password: 'secret123');
      expect(http.bodyOf('POST', '/auth/phone/login'), {'phone': '+7700', 'password': 'secret123'});

      http.fail('POST', '/auth/phone/login', 401);
      expect(await _errorKey(() => api.loginWithPhonePassword(phone: 'p', password: 'w')),
          AuthErrorKey.invalidCredentials);
      http.fail('POST', '/auth/phone/login', 429);
      expect(await _errorKey(() => api.loginWithPhonePassword(phone: 'p', password: 'w')),
          AuthErrorKey.tooManyLoginAttempts);
      http.fail('POST', '/auth/phone/login', 500);
      await expectLater(api.loginWithPhonePassword(phone: 'p', password: 'w'), throwsA(isA<DioException>()));
    });
  });
}
