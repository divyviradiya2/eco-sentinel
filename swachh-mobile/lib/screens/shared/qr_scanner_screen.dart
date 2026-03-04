import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import 'manual_location_picker.dart';

class QrScannerScreen extends StatefulWidget {
  final LocationService? locationService;

  const QrScannerScreen({super.key, this.locationService});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final LocationService _locationService;
  bool _isProcessing = false;
  final MobileScannerController controller = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Pause scanner to prevent multiple detections while processing
      await controller.stop();

      final location = await _locationService.getLocationByQrCodeId(code);
      if (!mounted) return;

      if (location != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isStudent = authProvider.appUser?.role == UserRole.student;

        if (location.restricted && isStudent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This location is restricted to Faculty reports only.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Resume scanner so user can try another code
          await controller.start();
        } else {
          Navigator.of(context).pop(location);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unknown QR code scanned. Try again or select manually.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Resume scanner so user can try another code
        await controller.start();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing QR code: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Location QR'),
        // Simpler app bar without flash/camera facing switches since mobile_scanner 7 API changed
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleBarcode,
            // errorBuilder helps to handle camera permissions gracefully fallback
            errorBuilder: (BuildContext context, MobileScannerException error) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Camera error: ${error.errorCode.name}',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final location = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ManualLocationPicker(
                              locationService: _locationService,
                            ),
                          ),
                        );
                        if (context.mounted && location != null) {
                          Navigator.of(context).pop(location);
                        }
                      },
                      child: const Text('Select Location Manually'),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  final location = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ManualLocationPicker(
                        locationService: _locationService,
                      ),
                    ),
                  );
                  if (context.mounted && location != null) {
                    Navigator.of(context).pop(location);
                  }
                },
                icon: const Icon(Icons.list),
                label: const Text('Select Location Manually'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
