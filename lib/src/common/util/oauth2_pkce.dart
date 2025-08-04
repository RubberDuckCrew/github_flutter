import 'dart:async';
import 'dart:convert';

import 'package:github_flutter/src/common.dart';
import 'package:http/http.dart' as http;

class OAuth2PKCE {
  /// OAuth2 Client ID
  final String clientId;

  /// Requested Scopes
  final List<String> scopes;

  /// Redirect URI
  final String? redirectUri;

  /// State
  final String? state;

  /// OAuth2 Base URL
  final String baseUrl;

  /// Confidential Intermediary Server URL
  final String confidentialIntermediaryServer;

  GitHub? github;

  /// Constructor to initialize [OAuth2PKCE] with required parameters.
  OAuth2PKCE(
    this.clientId,
    this.confidentialIntermediaryServer, {
    String? redirectUri,
    this.scopes = const [],
    this.state,
    this.github,
    this.baseUrl = 'https://github.com/login/oauth',
  }) : redirectUri =
           redirectUri == null ? null : _checkRedirectUri(redirectUri);

  static String _checkRedirectUri(String uri) {
    return uri.contains('?') ? uri.substring(0, uri.indexOf('?')) : uri;
  }

  /// Generates an Authorization URL
  ///
  /// This should be displayed to the user.
  String createAuthorizeUrl(String codeChallenge) {
    return '$baseUrl/authorize${buildQueryString({'client_id': clientId, 'scope': scopes.join(','), 'redirect_uri': redirectUri, 'state': state, 'code_challenge': codeChallenge, 'code_challenge_method': 'S256'})}';
  }

  Future<ExchangeResponse> exchange(
    String code,
    String codeVerifier, [
    String? origin,
  ]) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'content-type': 'application/json',
    };
    if (origin != null) {
      headers['Origin'] = origin;
    }

    final body = GitHubJson.encode(<String, dynamic>{
      'client_id': clientId,
      'code_verifier': codeVerifier,
      'code': code,
      'redirect_uri': redirectUri,
    });

    return (github == null ? http.Client() : github!.client)
        .post(
          Uri.parse(confidentialIntermediaryServer),
          body: body,
          headers: headers,
        )
        .then((response) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          if (json['error'] != null) {
            throw Exception(json['error']);
          }
          return ExchangeResponse(
            json['access_token'],
            json['token_type'],
            (json['scope'] as String).split(','),
          );
        });
  }
}
