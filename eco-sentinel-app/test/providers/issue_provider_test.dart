import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swachh_mobile/providers/issue_provider.dart';
import 'package:swachh_mobile/services/issue_service.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'dart:async';

class MockIssueService extends Mock implements IssueService {}

void main() {
  late IssueProvider issueProvider;
  late MockIssueService mockIssueService;

  setUp(() {
    mockIssueService = MockIssueService();
    issueProvider = IssueProvider(mockIssueService);
  });

  test('initial state is correct', () {
    expect(issueProvider.myIssues, []);
    expect(issueProvider.isLoading, false);
    expect(issueProvider.errorMessage, null);
  });

  test('listenToMyIssues updates state correctly', () async {
    final streamController = StreamController<List<IssueModel>>();
    when(
      () => mockIssueService.getMyIssuesStream('user1'),
    ).thenAnswer((_) => streamController.stream);

    issueProvider.listenToMyIssues('user1');

    expect(issueProvider.isLoading, true);
    expect(issueProvider.errorMessage, null);

    final mockIssue = IssueModel(
      id: '1',
      locationId: 'loc1',
      locationName: 'Location One',
      description: 'Test',
      imageUrl: 'img',
      reporterId: 'user1',
      status: 'Reported',
      createdAt: DateTime.now(),
    );

    streamController.add([mockIssue]);
    await Future.delayed(
      Duration.zero,
    ); // yield execution to let await in stream propagate

    expect(issueProvider.myIssues.length, 1);
    expect(issueProvider.myIssues.first.id, '1');
    expect(issueProvider.isLoading, false);

    streamController.addError(Exception('Stream error'));
    await Future.delayed(Duration.zero);

    expect(issueProvider.errorMessage, contains('Failed to load data'));
    expect(issueProvider.isLoading, false);

    streamController.close();
  });

  test('listenToWorkerTasks updates state correctly', () async {
    final streamController = StreamController<List<IssueModel>>();
    when(
      () => mockIssueService.getWorkerTasksStream('worker1'),
    ).thenAnswer((_) => streamController.stream);

    issueProvider.listenToWorkerTasks('worker1');

    expect(issueProvider.isLoading, true);
    expect(issueProvider.errorMessage, null);

    final mockTask = IssueModel(
      id: '2',
      locationId: 'loc2',
      locationName: 'Location Two',
      description: 'Task',
      imageUrl: 'img',
      reporterId: 'user1',
      status: 'Assigned',
      createdAt: DateTime.now(),
    );

    streamController.add([mockTask]);
    await Future.delayed(Duration.zero);

    expect(issueProvider.workerTasks.length, 1);
    expect(issueProvider.workerTasks.first.id, '2');
    expect(issueProvider.isLoading, false);

    streamController.addError(Exception('Stream error'));
    await Future.delayed(Duration.zero);

    expect(issueProvider.errorMessage, contains('Failed to load data'));
    expect(issueProvider.isLoading, false);

    streamController.close();
  });
}
