import 'package:flutter/material.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/services/auth_service.dart';

class WorkerSelectionDialog extends StatefulWidget {
  const WorkerSelectionDialog({super.key});

  @override
  State<WorkerSelectionDialog> createState() => _WorkerSelectionDialogState();
}

class _WorkerSelectionDialogState extends State<WorkerSelectionDialog> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<AppUser> _workers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  Future<void> _fetchWorkers() async {
    try {
      final workers = await _authService.getWorkers();
      if (mounted) {
        setState(() {
          _workers = workers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Worker'),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Text('Error: $_error', style: const TextStyle(color: Colors.red));
    }

    if (_workers.isEmpty) {
      return const Text('No workers found.');
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _workers.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final worker = _workers[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(worker.displayName),
          subtitle: Text('ID: ${worker.workerId ?? 'N/A'}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(worker.rating.toStringAsFixed(1)),
            ],
          ),
          onTap: () {
            Navigator.of(context).pop(worker);
          },
        );
      },
    );
  }
}
