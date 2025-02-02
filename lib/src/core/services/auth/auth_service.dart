import 'dart:convert';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:pkce/pkce.dart';
import 'package:spotify_flutter/src/core/api/api_client.dart';
import 'package:spotify_flutter/src/core/api/api_result.dart';
import 'package:spotify_flutter/src/core/api/network_exceptions.dart';
import 'package:spotify_flutter/src/core/constants/routes.dart';
import 'package:spotify_flutter/src/core/services/storage/storage_service.dart';

class AuthService {
  final _apiClient = ApiClient.instance;
  final _storageService = StorageService();

  Future<ApiResult<bool>> authorize(
      {required String redirectUri,
      required String clientId,
      String state = 'HappyBaby247',
      required String callbackUrlScheme,
      required String secretKey,
      String? scope}) async {
    final pkcePair = PkcePair.generate();

    final codeChallenge = pkcePair.codeChallenge.replaceAll('=', '');
    final codeVerifier = pkcePair.codeVerifier;

    final url = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'state': state,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      if (scope != null) 'scope': scope
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackUrlScheme,
      );

      final returnedState = Uri.parse(result).queryParameters['state'];

      if (state == returnedState) {
        final code = Uri.parse(result).queryParameters['code'];

        if (code != null) {
          return await _getToken(
            code: code,
            codeVerifier: codeVerifier,
            redirectUri: redirectUri,
            clientId: clientId,
            secretKey: secretKey,
          );
        }
      }
    } on Exception {
      return const ApiResult.failure(error: NetworkExceptions.unexpectedError());
    }
    return const ApiResult.failure(error: NetworkExceptions.unexpectedError());
  }

  Future<ApiResult<String>> getAuthToken(
      {required String redirectUri,
      required String clientId,
      String state = 'HappyBaby247',
      required String callbackUrlScheme,
      required String secretKey,
      String? scope}) async {

    final url = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'state': state,
      if (scope != null) 'scope': scope
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackUrlScheme,
      );

      final returnedState = Uri.parse(result).queryParameters['state'];

      if (state == returnedState) {
        final code = Uri.parse(result).queryParameters['code'];

        if (code != null) {
          return ApiResult<String>.success(data: code);
        }
      }
    } on Exception catch (e) {
      return const ApiResult.failure(error: NetworkExceptions.unexpectedError());
    }
    return const ApiResult.failure(error: NetworkExceptions.unexpectedError());
  }

  Future<ApiResult<bool>> _getToken({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    required String clientId,
    required String secretKey,
  }) async {
    final data = {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'code_verifier': codeVerifier
    };

    Codec<String, String> stringToBase64 = utf8.fuse(base64);

    final encodedString = stringToBase64.encode('$clientId:$secretKey');
    final header = {
      'Authorization': 'Basic $encodedString',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final response = await _apiClient.post(
      url: Routes.autGetTokenUrl,
      clientId: clientId,
      body: data,
      header: header,
      requiresToken: false,
    );

    late ApiResult<bool> result;

    response.when(success: (success) {
      result = ApiResult.success(data: success.statusCode == 200);
      _storageService.saveToken(accessToken: success.data['access_token'], refreshToken: success.data['refresh_token']);
      _storageService.saveClientId(clientId);
    }, failure: (failure) {
      result = ApiResult.failure(error: failure);
    });
    return result;
  }
}
