import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'preview_screen.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;

  const ResultScreen({super.key, required this.imageFile});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaving = false;
  bool _isSaved = false;
  String? _error;
  String _fileSizeStr = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final length = await widget.imageFile.length();
      final kb = length / 1024;
      if (kb > 1024) {
        setState(() {
          _fileSizeStr = '${(kb / 1024).toStringAsFixed(2)} MB';
        });
      } else {
        setState(() {
          _fileSizeStr = '${kb.toStringAsFixed(0)} KB';
        });
      }
    } catch (_) {
      setState(() {
        _fileSizeStr = 'Unknown';
      });
    }
  }

  Future<void> _saveToGallery() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImage(widget.imageFile.path);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('360° Panorama saved to Gallery!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Failed to save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '360° Panorama Result',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Image Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Image.file(
                      widget.imageFile,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Actions Card
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                left: 20,
                right: 20,
                top: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: const Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  // Metadata stats row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Format', 'Equirectangular PNG'),
                        Container(width: 1, height: 28, color: Colors.white12),
                        _buildStatItem('Aspect', '2 : 1 (360°)'),
                        Container(width: 1, height: 28, color: Colors.white12),
                        _buildStatItem('File Size', _fileSizeStr),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isSaved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Saved to Gallery successfully!',
                            style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || _isSaved ? null : _saveToGallery,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_isSaved ? Icons.check : Icons.save_alt, size: 22),
                      label: Text(
                        _isSaving
                            ? 'Saving to Gallery...'
                            : (_isSaved ? 'Saved in Gallery' : 'Save to Gallery'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSaved ? Colors.green.shade700 : const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _isSaved ? Colors.green.shade800 : Colors.white24,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bottom Secondary Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PreviewScreen(imageFile: widget.imageFile),
                            ),
                          );
                        },
                        icon: const Icon(Icons.threed_rotation, color: Color(0xFF00D2C4), size: 20),
                        label: const Text(
                          'View in 360°',
                          style: TextStyle(color: Color(0xFF00D2C4), fontSize: 14),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        icon: const Icon(Icons.home, color: Colors.white70, size: 20),
                        label: const Text(
                          'Back to Home',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
