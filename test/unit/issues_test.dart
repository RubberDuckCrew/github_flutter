import 'dart:convert';

import 'package:github_flutter/src/common.dart';
import 'package:github_flutter/src/common/graphql_service.dart';
import 'package:graphql/client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const String testIssueCommentJson = '''
  {
    "url": "https://api.github.com/repos/flutter/cocoon/issues/comments/1352355796",
    "html_url": "https://github.com/flutter/cocoon/pull/2356#issuecomment-1352355796",
    "issue_url": "https://api.github.com/repos/flutter/cocoon/issues/2356",
    "id": 1352355796,
    "node_id": "IC_kwDOA8VHis5Qm0_U",
    "user": {
      "login": "CaseyHillers",
      "id": 2148558,
      "node_id": "MDQ6VXNlcjIxNDg1NTg=",
      "avatar_url": "https://avatars.githubusercontent.com/u/2148558?v=4",
      "gravatar_id": "",
      "url": "https://api.github.com/users/CaseyHillers",
      "html_url": "https://github.com/CaseyHillers",
      "followers_url": "https://api.github.com/users/CaseyHillers/followers",
      "following_url": "https://api.github.com/users/CaseyHillers/following{/other_user}",
      "gists_url": "https://api.github.com/users/CaseyHillers/gists{/gist_id}",
      "starred_url": "https://api.github.com/users/CaseyHillers/starred{/owner}{/repo}",
      "subscriptions_url": "https://api.github.com/users/CaseyHillers/subscriptions",
      "organizations_url": "https://api.github.com/users/CaseyHillers/orgs",
      "repos_url": "https://api.github.com/users/CaseyHillers/repos",
      "events_url": "https://api.github.com/users/CaseyHillers/events{/privacy}",
      "received_events_url": "https://api.github.com/users/CaseyHillers/received_events",
      "type": "User",
      "site_admin": false
    },
    "created_at": "2022-12-14T23:26:32Z",
    "updated_at": "2022-12-14T23:26:32Z",
    "author_association": "MEMBER",
    "body": "FYI you need to run https://github.com/flutter/cocoon/blob/main/format.sh for formatting Cocoon code",
    "reactions": {
      "url": "https://api.github.com/repos/flutter/cocoon/issues/comments/1352355796/reactions",
      "total_count": 0,
      "+1": 0,
      "-1": 0,
      "laugh": 0,
      "hooray": 0,
      "confused": 0,
      "heart": 0,
      "rocket": 0,
      "eyes": 0
    },
    "performed_via_github_app": null
  }
''';

typedef GetJSONCallback =
    Future<T> Function<S, T>(
      String path, {
      int? statusCode,
      void Function(http.Response)? fail,
      Map<String, String>? headers,
      Map<String, String>? params,
      JSONConverter<S, T>? convert,
      String? preview,
    });

// A mock implementation of GitHub that uses noSuchMethod to avoid implementing
// all methods of the GitHub class.
class MockGitHub implements GitHub {
  @override
  late final GraphQLService graphql;

  late GetJSONCallback onGetJSON;

  MockGitHub(this.graphql);

  @override
  Future<T> getJSON<S, T>(
    String path, {
    int? statusCode,
    void Function(http.Response)? fail,
    Map<String, String>? headers,
    Map<String, String>? params,
    JSONConverter<S, T>? convert,
    String? preview,
  }) {
    return onGetJSON<S, T>(
      path,
      statusCode: statusCode,
      fail: fail,
      headers: headers,
      params: params,
      convert: convert,
      preview: preview,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // This is needed to avoid implementing all methods of the GitHub class.
    // We only care about getJSON and graphql.
  }
}

// A manual mock for GraphQLService to avoid mockito issues.
class MockGraphQLService implements GraphQLService {
  // Callback to be set by the test.
  late Future<QueryResult> Function(String, Map<String, dynamic>?) onMutate;

  @override
  Future<QueryResult> mutate(
    String mutation, {
    Map<String, dynamic>? variables,
  }) {
    return onMutate(mutation, variables);
  }

  // Unimplemented members
  @override
  GitHub get github => throw UnimplementedError();
  @override
  Future<QueryResult> query(String query, {Map<String, dynamic>? variables}) =>
      throw UnimplementedError();
}

void main() {
  group('Issue Comments', () {
    test('IssueComment from Json', () {
      final issueComment = IssueComment.fromJson(
        jsonDecode(testIssueCommentJson),
      );
      expect(1352355796, issueComment.id);
      expect('MEMBER', issueComment.authorAssociation);
      expect('CaseyHillers', issueComment.user!.login);
    });
  });

  group('IssuesService', () {
    late IssuesService issuesService;
    late MockGitHub mockGitHub;
    late MockGraphQLService mockGraphQLService;

    setUp(() {
      mockGraphQLService = MockGraphQLService();
      mockGitHub = MockGitHub(mockGraphQLService);
      issuesService = IssuesService(mockGitHub);
    });

    test('deleteIssue success', () async {
      // Arrange
      String? capturedMutation;
      Map<String, dynamic>? capturedVariables;
      final slug = RepositorySlug('owner', 'repo');
      const issueNumber = 1;
      const issueNodeId = 'issue-node-id-456';

      mockGitHub.onGetJSON = <S, T>(
        String path, {
        int? statusCode,
        void Function(http.Response)? fail,
        Map<String, String>? headers,
        Map<String, String>? params,
        JSONConverter<S, T>? convert,
        String? preview,
      }) async {
        if (path == '/repos/owner/repo/issues/1') {
          final issueJson = {
            'id': 1,
            'node_id': issueNodeId,
            'number': issueNumber,
            'state': 'open',
            'title': 'Test Issue',
            'url': 'https://api.github.com/repos/owner/repo/issues/1',
            'html_url': 'https://github.com/owner/repo/issues/1',
            'body': 'Test Body',
          };
          final issue = convert!(issueJson as S);
          return issue;
        }
        throw Exception('Unexpected path: $path');
      };

      mockGraphQLService.onMutate = (mutation, variables) {
        capturedMutation = mutation;
        capturedVariables = variables;
        return Future.value(
          QueryResult(
            options: QueryOptions(
              document: gql(''),
            ), // ignore: deprecated_member_use
            source: QueryResultSource.network,
            data: const {
              'deleteIssue': {'clientMutationId': '1234'},
            },
          ),
        );
      };

      // Act
      await issuesService.deleteIssue(slug, issueNumber);

      // Assert
      expect(capturedMutation, contains('mutation DeleteIssue'));
      expect(capturedVariables, {'issueId': issueNodeId});
    });

    test('deleteIssue failure on get', () async {
      // Arrange
      final slug = RepositorySlug('owner', 'repo');
      const issueNumber = 1;

      mockGitHub.onGetJSON = <S, T>(
        String path, {
        int? statusCode,
        void Function(http.Response)? fail,
        Map<String, String>? headers,
        Map<String, String>? params,
        JSONConverter<S, T>? convert,
        String? preview,
      }) async {
        throw Exception('Failed to get issue');
      };

      // Act & Assert
      expect(
        () => issuesService.deleteIssue(slug, issueNumber),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteIssue failure on mutate', () async {
      // Arrange
      final slug = RepositorySlug('owner', 'repo');
      const issueNumber = 1;
      const issueNodeId = 'issue-node-id-456';

      mockGitHub.onGetJSON = <S, T>(
        String path, {
        int? statusCode,
        void Function(http.Response)? fail,
        Map<String, String>? headers,
        Map<String, String>? params,
        JSONConverter<S, T>? convert,
        String? preview,
      }) async {
        if (path == '/repos/owner/repo/issues/1') {
          final issueJson = {
            'id': 1,
            'node_id': issueNodeId,
            'number': issueNumber,
            'state': 'open',
            'title': 'Test Issue',
            'url': 'https://api.github.com/repos/owner/repo/issues/1',
            'html_url': 'https://github.com/owner/repo/issues/1',
            'body': 'Test Body',
          };
          final issue = convert!(issueJson as S);
          return issue;
        }
        throw Exception('Unexpected path: $path');
      };

      final exception = OperationException(
        graphqlErrors: [const GraphQLError(message: 'Failed to delete')],
      );
      mockGraphQLService.onMutate = (mutation, variables) {
        return Future.value(
          QueryResult(
            options: QueryOptions(
              document: gql(''),
            ), // ignore: deprecated_member_use
            source: QueryResultSource.network,
            exception: exception,
          ),
        );
      };

      // Act & Assert
      expect(
        () => issuesService.deleteIssue(slug, issueNumber),
        throwsA(isA<OperationException>()),
      );
    });
  });
}
