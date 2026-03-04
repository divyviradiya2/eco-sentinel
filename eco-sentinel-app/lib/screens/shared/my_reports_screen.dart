import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/providers/issue_provider.dart';
import 'package:swachh_mobile/widgets/issue_card.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  @override
  void initState() {
    super.initState();
    // Start listening to the stream once the widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().appUser?.uid;
      if (userId != null) {
        context.read<IssueProvider>().listenToMyIssues(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: Consumer<IssueProvider>(
        builder: (context, issueProvider, child) {
          if (issueProvider.isLoading && issueProvider.myIssues.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (issueProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load reports',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      issueProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        final userId = context
                            .read<AuthProvider>()
                            .appUser
                            ?.uid;
                        if (userId != null) {
                          issueProvider.listenToMyIssues(userId);
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (issueProvider.myIssues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports found',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your reported issues will appear here',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: issueProvider.myIssues.length,
            itemBuilder: (context, index) {
              final issue = issueProvider.myIssues[index];
              return IssueCard(issue: issue);
            },
          );
        },
      ),
    );
  }
}
