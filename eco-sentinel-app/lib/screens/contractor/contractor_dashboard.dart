import 'package:flutter/material.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/services/issue_service.dart';
import 'package:swachh_mobile/widgets/issue_card.dart';
import 'package:swachh_mobile/models/user_model.dart';

import '../shared/settings_screen.dart';

class ContractorDashboardScreen extends StatefulWidget {
  const ContractorDashboardScreen({super.key});

  @override
  State<ContractorDashboardScreen> createState() =>
      _ContractorDashboardScreenState();
}

class _ContractorDashboardScreenState extends State<ContractorDashboardScreen> {
  final IssueService _issueService = IssueService();
  int _currentIndex = 0;
  late PageController _pageController;

  // Cache streams once to prevent re-subscription on rebuild
  late final Stream<List<IssueModel>> _reportedStream;
  late final Stream<List<IssueModel>> _activeStream;
  late final Stream<List<IssueModel>> _reviewStream;
  late final Stream<List<IssueModel>> _closedStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize streams once — they are broadcast by Firestore snapshots
    _reportedStream = _issueService.getReportedIssuesStream();
    _activeStream = _issueService.getActiveIssuesStream();
    _reviewStream = _issueService.getPendingReviewIssuesStream();
    _closedStream = _issueService.getClosedIssuesStream();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text(
          'Contractor Portal',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: [
              _KeepAliveIssueList(
                stream: _reportedStream,
                emptyTitle: 'No new reports',
                emptySubtitle: 'Great job maintaining quality!',
                emptyIcon: Icons.assignment_late_outlined,
              ),
              _KeepAliveIssueList(
                stream: _activeStream,
                emptyTitle: 'No active tasks',
                emptySubtitle: 'All assignments are covered',
                emptyIcon: Icons.engineering_outlined,
              ),
              _KeepAliveIssueList(
                stream: _reviewStream,
                emptyTitle: 'Review queue clear',
                emptySubtitle: 'You are all caught up',
                emptyIcon: Icons.rate_review_outlined,
              ),
              _KeepAliveIssueList(
                stream: _closedStream,
                emptyTitle: 'No closed history',
                emptySubtitle: 'Successfully resolved cases appear here',
                emptyIcon: Icons.task_alt_rounded,
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildFloatingDock(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingDock() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDockItem(0, Icons.assignment_late_outlined, 'Reported'),
          _buildDockItem(1, Icons.engineering_outlined, 'Active'),
          _buildDockItem(2, Icons.rate_review_outlined, 'Review'),
          _buildDockItem(3, Icons.task_alt_rounded, 'Closed'),
        ],
      ),
    );
  }

  Widget _buildDockItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final themeColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? themeColor : Colors.grey[600],
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A keep-alive wrapper that prevents PageView from disposing/rebuilding
/// tab content when the user swipes between pages. This eliminates the
/// loading flicker caused by stream re-subscription.
class _KeepAliveIssueList extends StatefulWidget {
  final Stream<List<IssueModel>> stream;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  const _KeepAliveIssueList({
    required this.stream,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  @override
  State<_KeepAliveIssueList> createState() => _KeepAliveIssueListState();
}

class _KeepAliveIssueListState extends State<_KeepAliveIssueList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    return StreamBuilder<List<IssueModel>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        // Show loading only on initial connection, not on data refresh
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        final issues = snapshot.data ?? [];

        if (issues.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.emptyIcon,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.emptyTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.emptySubtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
          itemCount: issues.length,
          itemBuilder: (context, index) {
            return IssueCard(
              issue: issues[index],
              userRole: UserRole.contractor,
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(Object? error) {
    final errorMsg = error?.toString() ?? 'Unknown error';
    final isIndexError =
        errorMsg.contains('index') ||
        errorMsg.contains('FAILED_PRECONDITION') ||
        errorMsg.contains('requires an index');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIndexError
                  ? Icons.build_circle_outlined
                  : Icons.error_outline_rounded,
              size: 64,
              color: isIndexError ? Colors.orange : Colors.red.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              isIndexError ? 'Optimizing Database...' : 'Something went wrong',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isIndexError
                  ? 'We are setting up the required search indexes. This only happens once and takes a few moments.'
                  : errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
