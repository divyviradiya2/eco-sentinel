import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:swachh_mobile/models/issue_model.dart';
import 'package:swachh_mobile/models/campus_location.dart';
import 'package:swachh_mobile/models/user_model.dart';
import 'package:swachh_mobile/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swachh_mobile/services/issue_service.dart';
import 'package:swachh_mobile/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:swachh_mobile/providers/auth_provider.dart';
import 'package:swachh_mobile/screens/contractor/worker_selection_dialog.dart';

class IssueDetailScreen extends StatefulWidget {
  final IssueModel issue;
  final UserRole userRole;
  final LocationService? locationService;
  final AuthService? authService;

  const IssueDetailScreen({
    super.key,
    required this.issue,
    required this.userRole,
    this.locationService,
    this.authService,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen>
    with SingleTickerProviderStateMixin {
  late final LocationService _locationService;
  late final AuthService _authService;
  late IssueModel _currentIssue;
  CampusLocation? _location;
  bool _isLoadingLocation = true;
  String? _locationError;

  AppUser? _assignedWorker;
  bool _isLoadingWorker = false;
  AppUser? _assignedContractor;
  bool _isLoadingContractor = false;

  late AnimationController _contentController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIssue = widget.issue;
    _locationService = widget.locationService ?? LocationService();
    _authService = widget.authService ?? AuthService();
    _fetchLocationDetails();
    _fetchWorkerDetails();
    _fetchContractorDetails();

    // Initialize Animations
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.2, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );

    // Start animation after a slight delay to allow Hero to breathe
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationDetails() async {
    try {
      final location = await _locationService.getLocationById(
        _currentIssue.locationId,
      );
      if (mounted) {
        setState(() {
          _location = location;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to load location details';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _fetchWorkerDetails() async {
    if (_currentIssue.assignedWorkerId == null) return;

    setState(() => _isLoadingWorker = true);
    try {
      final worker = await _authService.getUserById(
        _currentIssue.assignedWorkerId!,
      );
      if (mounted) {
        setState(() {
          _assignedWorker = worker;
          _isLoadingWorker = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching worker details: $e');
      if (mounted) {
        setState(() => _isLoadingWorker = false);
      }
    }
  }

  Future<void> _fetchContractorDetails() async {
    if (_currentIssue.assignedByContractorId == null) {
      debugPrint('No contractor ID found for issue ${_currentIssue.id}');
      return;
    }

    setState(() => _isLoadingContractor = true);
    try {
      debugPrint(
        'Fetching contractor details for UID: ${_currentIssue.assignedByContractorId}',
      );
      final contractor = await _authService.getUserById(
        _currentIssue.assignedByContractorId!,
      );
      if (mounted) {
        setState(() {
          _assignedContractor = contractor;
          _isLoadingContractor = false;
        });
        debugPrint('Contractor found: ${contractor?.displayName}');
      }
    } catch (e) {
      debugPrint('Error fetching contractor details: $e');
      if (mounted) {
        setState(() => _isLoadingContractor = false);
      }
    }
  }

  Future<void> _launchMaps() async {
    if (_location == null && _currentIssue.exactCoordinates == null) return;

    final lat =
        _currentIssue.exactCoordinates?.latitude ??
        _location?.coordinates.latitude ??
        0.0;
    final lng =
        _currentIssue.exactCoordinates?.longitude ??
        _location?.coordinates.longitude ??
        0.0;
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch maps application')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching maps: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a reporter (Student/Faculty) viewing an issue that is Assigned or In_Progress
    final isReporterAssigned =
        (widget.userRole == UserRole.student ||
            widget.userRole == UserRole.faculty) &&
        (_currentIssue.status == 'Assigned' ||
            _currentIssue.status == 'In_Progress');

    final isReporterReview =
        (widget.userRole == UserRole.student ||
            widget.userRole == UserRole.faculty) &&
        _currentIssue.status == 'Completed_Pending_Review';

    final isReporterClosed =
        (widget.userRole == UserRole.student ||
            widget.userRole == UserRole.faculty) &&
        _currentIssue.status == 'Closed';

    final isReporterPending =
        (widget.userRole == UserRole.student ||
            widget.userRole == UserRole.faculty) &&
        _currentIssue.status == 'Reported';

    final isContractorAssigned =
        widget.userRole == UserRole.contractor &&
        (_currentIssue.status == 'Assigned' ||
            _currentIssue.status == 'In_Progress' ||
            _currentIssue.status == 'Completed_Pending_Review' ||
            _currentIssue.status == 'Closed');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Issue Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (widget.userRole == UserRole.contractor &&
              _currentIssue.status == 'Reported')
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'spam') {
                  _showSpamConfirmationDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'spam',
                  child: Row(
                    children: [
                      Icon(Icons.report, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Flag as Spam', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_currentIssue.status == 'Completed_Pending_Review' ||
                    _currentIssue.status == 'Closed') &&
                _currentIssue.completionImageUrl != null)
              _buildComparisonView()
            else
              GestureDetector(
                onTap: _currentIssue.imageUrl.isNotEmpty
                    ? () =>
                          _openFullScreenImage(context, _currentIssue.imageUrl)
                    : null,
                child: Hero(
                  tag: 'issue_image_${_currentIssue.id}',
                  child: ClipRRect(
                    child: _currentIssue.imageUrl.isNotEmpty
                        ? Image.network(
                            _currentIssue.imageUrl,
                            width: double.infinity,
                            height: 300,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _LargeImagePlaceholder(),
                          )
                        : _LargeImagePlaceholder(),
                  ),
                ),
              ),
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatusBadge(status: _currentIssue.status),
                          Text(
                            DateFormat(
                              'MMM dd, yyyy • hh:mm a',
                            ).format(_currentIssue.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentIssue.locationName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentIssue.description,
                        style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                      ),
                      // Role-specific Assigned/Completed Worker Info
                      if ((isReporterAssigned ||
                              isReporterReview ||
                              isReporterClosed ||
                              isContractorAssigned) &&
                          (_isLoadingWorker || _assignedWorker != null)) ...[
                        const SizedBox(height: 24),
                        _buildWorkerInfoCard(),
                      ],
                      // ONLY show location card if NOT a reporter viewing a pending, assigned, review, or closed issue
                      if (!isReporterPending &&
                          !isReporterAssigned &&
                          !isReporterReview &&
                          !isReporterClosed) ...[
                        const SizedBox(height: 24),
                        _buildLocationCard(),
                      ],
                      if (_currentIssue.status == 'Assigned' &&
                          _currentIssue.rejectionNotes != null)
                        _buildRejectionNotes(),
                      if (_currentIssue.status == 'Closed')
                        _buildFeedbackSection(),
                      const SizedBox(height: 32),
                      _buildActionButton(),
                      if (widget.userRole == UserRole.worker &&
                          _currentIssue.status == 'Assigned')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: Text(
                              'Completion evidence required at location',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[500],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.engineering,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentIssue.status == 'Completed_Pending_Review' ||
                              _currentIssue.status == 'Closed'
                          ? 'Completed by'
                          : 'Assigned Personnel',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isLoadingWorker)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        ),
                      )
                    else
                      Text(
                        _assignedWorker?.displayName ?? 'Worker Identified',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                  ],
                ),
              ),
              if (!_isLoadingWorker && _assignedWorker != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _assignedWorker!.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Contractor attribution section - Always show for assigned issues
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Colors.blue),
          ),
          Row(
            children: [
              Icon(
                Icons.assignment_ind_outlined,
                color: Colors.blue[400],
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Assigned by: ',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              if (_isLoadingContractor)
                const SizedBox(
                  height: 10,
                  width: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.blue,
                  ),
                )
              else
                Text(
                  _assignedContractor?.displayName ??
                      (_currentIssue.assignedByContractorId != null
                          ? 'Management Personnel'
                          : 'Management'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentIssue.status == 'Completed_Pending_Review'
                ? 'Work has been completed and is awaiting your final verification.'
                : _currentIssue.status == 'Closed'
                ? 'This issue has been successfully resolved and closed.'
                : _currentIssue.status == 'Assigned'
                ? 'Personnel has been notified and is preparing for the task.'
                : 'Maintenance work is currently in progress at the location.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[800],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final feedback =
        _currentIssue.reporterFeedback ?? _currentIssue.contractorFeedback;
    final rating =
        _currentIssue.ratingByReporter ?? _currentIssue.verificationRating;

    if (feedback == null && rating == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Resolution Feedback',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
              const Spacer(),
              if (rating != null)
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber[700],
                    );
                  }),
                ),
            ],
          ),
          if (feedback != null && feedback.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              feedback,
              style: TextStyle(color: Colors.green[800], fontSize: 14),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _currentIssue.reporterFeedback != null
                ? 'Verified by Reporter'
                : 'Verified by Contractor',
            style: TextStyle(
              fontSize: 11,
              color: Colors.green[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(
    BuildContext context,
    String imageUrl, {
    String? heroTag,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, illumination, secondary) => FullScreenImage(
          imageUrl: imageUrl,
          heroTag: heroTag ?? 'issue_image_${_currentIssue.id}',
        ),
        transitionsBuilder: (context, animation, secondary, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildComparisonView() {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildComparisonImage(
                _currentIssue.imageUrl,
                'BEFORE (REPORTED)',
                'issue_image_${_currentIssue.id}',
              ),
              _buildComparisonImage(
                _currentIssue.completionImageUrl!,
                'AFTER (CLEANED)',
                'completion_image_${_currentIssue.id}',
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.black.withValues(alpha: 0.05),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_left_alt_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'Swipe to compare photos',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonImage(String url, String label, String heroTag) {
    return GestureDetector(
      onTap: () => _openFullScreenImage(context, url, heroTag: heroTag),
      child: Stack(
        children: [
          Hero(
            tag: heroTag,
            child: Image.network(
              url,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _LargeImagePlaceholder(),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionNotes() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'REJECTION REASON',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                    letterSpacing: 0.5,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currentIssue.rejectionNotes ?? '',
              style: TextStyle(color: Colors.red[900], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (widget.userRole == UserRole.contractor) {
      if (_currentIssue.status == 'Reported') {
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _showAssignmentDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text(
              'ASSIGN WORKER',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (_currentIssue.status == 'Completed_Pending_Review') {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _handleReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text(
                    'REJECT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.verified),
                  label: const Text(
                    'VERIFY',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    } else if (widget.userRole == UserRole.student ||
        widget.userRole == UserRole.faculty) {
      if (_currentIssue.status == 'Completed_Pending_Review') {
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _handleReporterVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text(
              'VERIFY & CLOSE REPORT',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } else if (widget.userRole == UserRole.worker) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed:
              _currentIssue.status == 'Completed_Pending_Review' ||
                  _currentIssue.status == 'Closed'
              ? null
              : _handleCompleteTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text(
            'COMPLETE TASK',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleVerify() async {
    int selectedRating = 0;
    final feedbackController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Verify & Close Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rate the quality of work (1-5 stars):'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text('Feedback (Optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: feedbackController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Work done efficiently!',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: selectedRating == 0
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'rating': selectedRating,
                        'feedback': feedbackController.text.trim(),
                      });
                    },
              child: const Text('VERIFY & CLOSE'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final issueService = IssueService();
        await issueService.verifyTask(
          _currentIssue.id,
          rating: result['rating'],
          feedback: result['feedback'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task verified and closed!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to verify: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejecting this work. The task will be sent back to the worker.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g., Area still not fully cleaned',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            child: const Text('REJECT'),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        final issueService = IssueService();
        await issueService.rejectTask(_currentIssue.id, reason);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task rejected and sent back to worker'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReporterVerify() async {
    int selectedRating = 0;
    final feedbackController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Verify & Close Your Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How was the resolution? (1-5 stars):'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text('Add any feedback for the worker:'),
              const SizedBox(height: 8),
              TextField(
                controller: feedbackController,
                decoration: const InputDecoration(
                  hintText: 'e.g., The area is perfectly clean now!',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: selectedRating == 0
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'rating': selectedRating,
                        'feedback': feedbackController.text.trim(),
                      });
                    },
              child: const Text('CONFIRM & CLOSE'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final issueService = IssueService();
        await issueService.verifyTaskByReporter(
          _currentIssue.id,
          rating: result['rating'],
          feedback: result['feedback'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you! Your report has been closed.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to close report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSpamConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flag as Spam?'),
        content: const Text(
          'This action cannot be undone. It will remove this issue from the queue and penalize the student who reported it. Are you sure this is a fake or inappropriate report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('FLAG AS SPAM'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        final issueService = IssueService();
        await issueService.flagIssueAsSpam(
          _currentIssue.id,
          _currentIssue.reporterId,
        );

        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context); // pop loading
        Navigator.pop(context); // exit screen

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Issue flagged as spam and reporter penalized.'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context); // pop loading
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to flag issue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAssignmentDialog() async {
    final AppUser? worker = await showDialog<AppUser>(
      context: context,
      builder: (context) => const WorkerSelectionDialog(),
    );

    if (worker != null) {
      // Guard BuildContext usage after async gap
      if (!mounted) return;
      final contractorId = context.read<AuthProvider>().appUser?.uid;
      if (contractorId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contractor session expired'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      try {
        final issueService = IssueService();
        await issueService.assignTask(
          _currentIssue.id,
          worker.uid,
          contractorId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task assigned to ${worker.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to assign task: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCompleteTask() async {
    final targetLat =
        _currentIssue.exactCoordinates?.latitude ??
        _location?.coordinates.latitude;
    final targetLng =
        _currentIssue.exactCoordinates?.longitude ??
        _location?.coordinates.longitude;

    if (targetLat == null || targetLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot verify location. Location data missing.'),
        ),
      );
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      Position currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        targetLat,
        targetLng,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (distanceInMeters > 50) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Verification Failed'),
            content: Text(
              'You must be at the location to complete this task.\n\nCurrent distance: ${distanceInMeters.toStringAsFixed(1)} meters.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      _showCompletionPhotoCapture();
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error validating location: $e')));
    }
  }

  void _showCompletionPhotoCapture() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        _submitCompletion(File(photo.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitCompletion(File imageFile) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading completion photo...'),
          ],
        ),
      ),
    );

    try {
      final issueService = IssueService();
      await issueService.completeTask(_currentIssue.id, imageFile);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task completed!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildLocationCard() {
    if (_isLoadingLocation) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Text('Loading coordinates...'),
            ],
          ),
        ),
      );
    }

    if (_locationError != null || _location == null) {
      return Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.location_off, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _locationError ?? 'Location data unavailable',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Location Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _location?.description ?? 'N/A',
              style: TextStyle(color: Colors.blue[800], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Coordinates: ${(_currentIssue.exactCoordinates?.latitude ?? _location?.coordinates.latitude ?? 0.0).toStringAsFixed(6)}, ${(_currentIssue.exactCoordinates?.longitude ?? _location?.coordinates.longitude ?? 0.0).toStringAsFixed(6)}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _launchMaps,
                icon: const Icon(Icons.directions),
                label: const Text('GET DIRECTIONS'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No issue photo available',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Reported':
        color = Colors.grey;
        break;
      case 'Assigned':
        color = Colors.blue;
        break;
      case 'In_Progress':
        color = Colors.orange;
        break;
      case 'Completed_Pending_Review':
        color = Colors.purple;
        break;
      case 'Closed':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
