import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_provider.dart';
import '../../widgets/issue_card.dart';
import 'settings_screen.dart';
import 'qr_scanner_screen.dart';
import 'report_issue_screen.dart';
import 'leaderboard_screen.dart';
import '../../models/campus_location.dart';
import '../../models/issue_model.dart';

class ReporterDashboard extends StatefulWidget {
  final String title;
  const ReporterDashboard({super.key, required this.title});

  @override
  State<ReporterDashboard> createState() => _ReporterDashboardState();
}

class _ReporterDashboardState extends State<ReporterDashboard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().appUser?.uid;
      if (userId != null) {
        context.read<IssueProvider>().listenToMyIssues(userId);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issueProvider = context.watch<IssueProvider>();

    // Filter issues by status for Student/Faculty visibility
    final pendingIssues = issueProvider.myIssues
        .where((i) => i.status == 'Reported')
        .toList();
    final assignedIssues = issueProvider.myIssues
        .where((i) => i.status == 'Assigned' || i.status == 'In_Progress')
        .toList();
    final reviewIssues = issueProvider.myIssues
        .where((i) => i.status == 'Completed_Pending_Review')
        .toList();
    final closedIssues = issueProvider.myIssues
        .where((i) => i.status == 'Closed')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Leaderboard',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              _buildIssueTab(
                issues: pendingIssues,
                emptyTitle: 'No Pending Reports',
                emptySubtitle: 'Issues you report will appear here',
                emptyIcon: Icons.assignment_late_outlined,
                showReportButton: true,
              ),
              _buildIssueTab(
                issues: assignedIssues,
                emptyTitle: 'No Active Assignments',
                emptySubtitle: 'Personnel are not yet on the way',
                emptyIcon: Icons.engineering_outlined,
              ),
              _buildIssueTab(
                issues: reviewIssues,
                emptyTitle: 'Nothing to Review',
                emptySubtitle: 'Completed tasks waiting for your verification',
                emptyIcon: Icons.rate_review_outlined,
              ),
              _buildIssueTab(
                issues: closedIssues,
                emptyTitle: 'No Closed Issues',
                emptySubtitle: 'Resolved issues will be archived here',
                emptyIcon: Icons.task_alt_outlined,
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

  Widget _buildIssueTab({
    required List<IssueModel> issues,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    bool showReportButton = false,
  }) {
    if (issues.isEmpty && !showReportButton) {
      return _buildEmptyState(emptyIcon, emptyTitle, emptySubtitle);
    }

    if (issues.isEmpty && showReportButton) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildEmptyState(emptyIcon, emptyTitle, emptySubtitle),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _buildReportButton(),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: issues.length + (showReportButton ? 1 : 0),
      itemBuilder: (context, index) {
        if (showReportButton && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _buildReportButton(),
          );
        }
        final issue = issues[showReportButton ? index - 1 : index];
        return IssueCard(
          issue: issue,
          userRole: context.read<AuthProvider>().appUser?.role,
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 64, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildReportButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _startReportFlow,
        icon: const Icon(Icons.qr_code_scanner, size: 22),
        label: const Text(
          'Report New Issue',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _startReportFlow() async {
    final location = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (location != null && location is CampusLocation && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportIssueScreen(location: location),
        ),
      );
    }
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
          _buildDockItem(0, Icons.assignment_late_outlined, 'Pending'),
          _buildDockItem(1, Icons.engineering_outlined, 'Assigned'),
          _buildDockItem(2, Icons.rate_review_outlined, 'Review'),
          _buildDockItem(3, Icons.task_alt_outlined, 'Closed'),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
