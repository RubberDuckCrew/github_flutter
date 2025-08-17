import 'dart:async';

import 'package:graphql/client.dart';

import 'github.dart';

/// Service for handling GraphQL requests.
class GraphQLService {
  final GitHub github;
  late final GraphQLClient _client;

  GraphQLService(this.github) {
    final httpLink = HttpLink('https://api.github.com/graphql');

    final authLink = AuthLink(
      getToken: () async => 'Bearer ${github.auth.token}',
    );

    final link = authLink.concat(httpLink);

    _client = GraphQLClient(cache: GraphQLCache(), link: link);
  }

  /// Performs a GraphQL query.
  Future<QueryResult> query(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final options = QueryOptions(
      document: gql(query),
      variables: variables ?? const <String, dynamic>{},
    );
    return _client.query(options);
  }

  /// Performs a GraphQL mutation.
  Future<QueryResult> mutate(
    String mutation, {
    Map<String, dynamic>? variables,
  }) async {
    final options = MutationOptions(
      document: gql(mutation),
      variables: variables ?? const <String, dynamic>{},
    );
    return _client.mutate(options);
  }
}
