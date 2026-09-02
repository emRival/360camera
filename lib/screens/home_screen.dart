import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/capture_config.dart';
import 'capture_screen.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CaptureConfig _selectedConfig = CaptureConfig.horizontal360;
  List<File> _savedPanoramas = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPanoramas();
  }

  Future<void> _loadSavedPanoramas() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      final files = entities
          .whereType<File>()
          .where((f) => f.path.contains('panorama_360_') && f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (mounted) {
        setState(() {
          _savedPanoramas = files;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates, color: Color(0xFF00D2C4)),
            SizedBox(width: 10),
            Text('Pro Tips for 360° Photos', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TipItem(
                step: '1',
                title: 'Keep Phone in One Spot',
                description:
                    'Rotate your body around the phone camera sensor like a pivot, rather than swinging your arms.',
              ),
              SizedBox(height: 12),
              _TipItem(
                step: '2',
                title: 'Align the Guide Dot',
                description:
                    'Follow the target dot into the center ring. When it turns green, it snaps automatically.',
              ),
              SizedBox(height: 12),
              _TipItem(
                step: '3',
                title: 'Consistent Lighting',
                description:
                    'Use the Exposure Lock button if moving between bright sun and shadows.',
              ),
              SizedBox(height: 12),
              _TipItem(
                step: '4',
                title: 'Seamless 360° Result',
                description:
                    'OpenCV will stitch all images into an equirectangular PNG you can view in VR or 360 mode.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It!', style: TextStyle(color: Color(0xFF00D2C4))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.threed_rotation, color: Color(0xFF00D2C4), size: 28),
                        SizedBox(width: 10),
                        Text(
                          '360 Picture',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline, color: Colors.white70),
                      tooltip: 'Guide & Tips',
                      onPressed: _showHowItWorksDialog,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A73E8), Color(0xFF00D2C4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D2C4).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.camera_alt, color: Colors.white, size: 28),
                                SizedBox(width: 10),
                                Text(
                                  '360° Photosphere',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Capture full panoramic spheres with guided sensor tracking and OpenCV stitching.',
                              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CaptureScreen(config: _selectedConfig),
                                    ),
                                  );
                                  _loadSavedPanoramas();
                                },
                                icon: const Icon(Icons.play_arrow, size: 24),
                                label: Text(
                                  'Start ${_selectedConfig.title}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1A1A2E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Mode Selection Header
                      const Text(
                        'Select Capture Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Mode Options Cards
                      _buildModeCard(
                        config: CaptureConfig.horizontal360,
                        icon: Icons.panorama_horizontal,
                        badge: 'RECOMMENDED',
                      ),
                      const SizedBox(height: 10),
                      _buildModeCard(
                        config: CaptureConfig.photosphere,
                        icon: Icons.threed_rotation,
                        badge: 'FULL SPHERE',
                      ),
                      const SizedBox(height: 10),
                      _buildModeCard(
                        config: CaptureConfig.wide180,
                        icon: Icons.panorama,
                        badge: 'QUICK SWEEP',
                      ),

                      const SizedBox(height: 24),

                      // Previous Panoramas History
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your 360° Panoramas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_savedPanoramas.isNotEmpty)
                            Text(
                              '${_savedPanoramas.length} photos',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_isLoadingHistory)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: Color(0xFF00D2C4)),
                          ),
                        )
                      else if (_savedPanoramas.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.photo_library_outlined, size: 48, color: Colors.white38),
                              SizedBox(height: 12),
                              Text(
                                'No 360° panoramas yet',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Capture your first 360° photo to view it here',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _savedPanoramas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final file = _savedPanoramas[index];
                            final modified = file.lastModifiedSync();
                            final dateStr =
                                '${modified.day}/${modified.month}/${modified.year}  ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    file,
                                    width: 60,
                                    height: 45,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: const Text(
                                  '360° Panorama',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  dateStr,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                trailing: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.threed_rotation, color: Color(0xFF00D2C4), size: 20),
                                    SizedBox(width: 6),
                                    Icon(Icons.chevron_right, color: Colors.white38),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PreviewScreen(imageFile: file),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required CaptureConfig config,
    required IconData icon,
    required String badge,
  }) {
    final isSelected = _selectedConfig.mode == config.mode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedConfig = config;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A73E8).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00D2C4) : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF00D2C4).withValues(alpha: 0.2)
                    : Colors.white10,
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF00D2C4) : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        config.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF00D2C4) : Colors.white12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Radio<CaptureMode>(
              value: config.mode,
              groupValue: _selectedConfig.mode,
              activeColor: const Color(0xFF00D2C4),
              onChanged: (_) {
                setState(() {
                  _selectedConfig = config;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String step;
  final String title;
  final String description;

  const _TipItem({
    required this.step,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF00D2C4),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
