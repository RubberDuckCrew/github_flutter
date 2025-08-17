import 'dart:convert';

import 'package:github_flutter/src/common.dart';
import 'package:github_flutter/src/common/graphql_service.dart';
import 'package:graphql/client.dart';
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

// A mock implementation of GitHub that uses noSuchMethod to avoid implementing
// all methods of the GitHub class.
class MockGitHub implements GitHub {
  @override
  late final GraphQLService graphql;

  MockGitHub(this.graphql);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
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

      mockGraphQLService.onMutate = (mutation, variables) {
        capturedMutation = mutation;
        capturedVariables = variables;
        return Future.value(
          QueryResult(
            options: QueryOptions(document: gql('')),
            source: QueryResultSource.network,
            data: const {
              'deleteIssue': {'clientMutationId': '1234'},
            },
          ),
        );
      };

      // Act
      await issuesService.deleteIssue('issue-id-123');

      // Assert
      expect(capturedMutation, contains('mutation DeleteIssue'));
      expect(capturedVariables, {'issueId': 'issue-id-123'});
    });

    test('deleteIssue failure', () async {
      // Arrange
      final exception = OperationException(
        graphqlErrors: [const GraphQLError(message: 'Failed to delete')],
      );
      mockGraphQLService.onMutate = (mutation, variables) {
        return Future.value(
          QueryResult(
            options: QueryOptions(document: gql('')),
            source: QueryResultSource.network,
            exception: exception,
          ),
        );
      };

      // Act & Assert
      expect(
        () => issuesService.deleteIssue('issue-id-123'),
        throwsA(isA<OperationException>()),
      );
    });
  });
}
