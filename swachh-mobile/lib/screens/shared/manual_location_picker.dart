import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/campus_location.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';

class ManualLocationPicker extends StatefulWidget {
  final LocationService? locationService;

  const ManualLocationPicker({super.key, this.locationService});

  @override
  State<ManualLocationPicker> createState() => _ManualLocationPickerState();
}

class _ManualLocationPickerState extends State<ManualLocationPicker> {
  late final LocationService _locationService;
  List<CampusLocation> _allLocations = [];
  List<CampusLocation> _filteredLocations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService();
    // Schedule fetch after first frame to avoid calling context.read in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLocations();
    });
  }

  Future<void> _fetchLocations() async {
    if (!mounted) return;
    try {
      final locations = await _locationService.getLocations();
      if (!mounted) return;

      final userRole =
          context.read<AuthProvider>().appUser?.role ?? UserRole.student;

      setState(() {
        _allLocations = locations.where((loc) {
          if (userRole == UserRole.student) {
            return !loc.restricted;
          }
          return true;
        }).toList();
        _filteredLocations = _allLocations;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading locations: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterLocations(String query) {
    setState(() {
      _searchQuery = query;
      _filteredLocations = _allLocations.where((loc) {
        final nameMatches = loc.name.toLowerCase().contains(
          query.toLowerCase(),
        );
        final descMatches = loc.description.toLowerCase().contains(
          query.toLowerCase(),
        );
        return nameMatches || descMatches;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search locations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterLocations('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterLocations,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLocations.isEmpty
                ? const Center(child: Text('No locations found'))
                : ListView.separated(
                    itemCount: _filteredLocations.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final location = _filteredLocations[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: location.restricted
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            location.restricted
                                ? Icons.lock
                                : Icons.location_on,
                            color: location.restricted
                                ? Colors.orange
                                : Colors.blue,
                          ),
                        ),
                        title: Text(
                          location.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(location.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop(location);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
