import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/services/issue_service.dart';

class IssueProvider with ChangeNotifier {
  final IssueService _issueService;
  StreamSubscription<List<IssueModel>>? _subscription;

  List<IssueModel> _myIssues = [];
  List<IssueModel> _workerTasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  IssueProvider(this._issueService);

  List<IssueModel> get myIssues => _myIssues;
  List<IssueModel> get workerTasks => _workerTasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void listenToMyIssues(String userId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _issueService.getMyIssuesStream(userId).listen((issues) {
      _myIssues = issues;
      _isLoading = false;
      notifyListeners();
    }, onError: _handleError);
  }

  void listenToWorkerTasks(String workerId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _issueService.getWorkerTasksStream(workerId).listen((
      tasks,
    ) {
      _workerTasks = tasks;
      _isLoading = false;
      notifyListeners();
    }, onError: _handleError);
  }

  void _handleError(Object error) {
    if (error.toString().contains('failed-precondition')) {
      _errorMessage =
          'A required database index is missing or being optimized. Please report this to the administrator.';
    } else if (error.toString().contains('permission-denied')) {
      _errorMessage = 'You do not have permission to view this data.';
    } else {
      _errorMessage = 'Failed to load data. Please check your connection.';
    }
    // Log technical error for developers
    debugPrint('Firestore Error: $error');
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
