import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/providers/issue_provider.dart';
import 'package:swachh_mobile/widgets/issue_card.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/models/user_model.dart';

import '../shared/settings_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appUser = context.read<AuthProvider>().appUser;
      final workerId = appUser?.uid;

      if (workerId != null) {
        context.read<IssueProvider>().listenToWorkerTasks(workerId);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text(
          'Worker Portal',
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
          Consumer<IssueProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                );
              }

              if (provider.errorMessage != null) {
                return _buildErrorState(provider);
              }

              final allTasks = provider.workerTasks;

              final assignedTasks = allTasks
                  .where(
                    (t) => t.status == 'Assigned' || t.status == 'In_Progress',
                  )
                  .toList();

              final pendingTasks = allTasks
                  .where((t) => t.status == 'Completed_Pending_Review')
                  .toList();

              final verifiedTasks = allTasks
                  .where((t) => t.status == 'Closed')
                  .toList();

              return PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: [
                  _buildTaskList(
                    assignedTasks,
                    'No tasks assigned',
                    Icons.assignment_turned_in_outlined,
                    'Keep it up!',
                  ),
                  _buildTaskList(
                    pendingTasks,
                    'Nothing pending',
                    Icons.hourglass_empty_outlined,
                    'You are all caught up',
                  ),
                  _buildTaskList(
                    verifiedTasks,
                    'No verified tasks',
                    Icons.verified_user_outlined,
                    'Completed tasks will appear here',
                  ),
                ],
              );
            },
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
          _buildDockItem(0, Icons.assignment_outlined, 'Assigned'),
          _buildDockItem(1, Icons.pending_actions_outlined, 'Pending'),
          _buildDockItem(2, Icons.verified_outlined, 'Verified'),
        ],
      ),
    );
  }

  Widget _buildDockItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    const themeColor = Colors.green;

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
                style: const TextStyle(
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

  Widget _buildTaskList(
    List<IssueModel> tasks,
    String emptyMessage,
    IconData emptyIcon,
    String subMessage,
  ) {
    if (tasks.isEmpty) {
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
              child: Icon(emptyIcon, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subMessage,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 100), // Space for bottom dock
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.green,
      onRefresh: () async {
        final appUser = context.read<AuthProvider>().appUser;
        if (appUser?.uid != null) {
          context.read<IssueProvider>().listenToWorkerTasks(appUser!.uid);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          0,
          8,
          0,
          100,
        ), // Extra padding for dock
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return IssueCard(issue: tasks[index], userRole: UserRole.worker);
        },
      ),
    );
  }

  Widget _buildErrorState(IssueProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load tasks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final appUser = context.read<AuthProvider>().appUser;
                if (appUser?.uid != null) {
                  provider.listenToWorkerTasks(appUser!.uid);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
