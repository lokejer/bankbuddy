import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'screens/dashboard_screen.dart';

// Values injected at build time via --dart-define
// Fallbacks are empty strings so the app fails loudly if not provided
const String baseUrl = String.fromEnvironment('BASE_URL');
const String sessionId = String.fromEnvironment('SESSION_ID');

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BankBuddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Lato'),
      home: const UploadScreen(),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  // Design tokens — mirrors the rest of the app
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _surfaceElevated = Color(0xFF222222);
  static const _border = Color(0xFF2A2A2A);
  static const _orange = Color(0xFFFF6B00);
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF888888);
  static const _errorRed = Color(0xFFFF3B3B);

  PlatformFile? _pickedFile;
  final _monthController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Tracks whether the upload zone is being pressed for press-state feedback
  bool _uploadZonePressed = false;

  // Bounce animation controller for the upload icon
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    // Gentle idle loop on the upload icon
    _bounceController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        _pickedFile = result.files.single;
        _error = null;
        // Stop idle bounce once a file is selected
        _bounceController.stop();
      });
    }
  }
  Future<void> _upload() async {
    final raw = _monthController.text.trim();

    if (_pickedFile == null) {
      setState(() => _error = 'Please select a PDF statement first.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(raw)) {
      setState(() => _error = 'Enter 6 digits, e.g. 202601 for Jan 2026.');
      return;
    }

    final year = raw.substring(0, 4);
    final monthInt = int.parse(raw.substring(4, 6));
    if (monthInt < 1 || monthInt > 12) {
      setState(() => _error = 'Month must be 01–12.');
      return;
    }

    // YYYY-MM format for the dashboard route
    final month = '$year-${raw.substring(4, 6)}';

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final monthNames = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final monthName = monthNames[monthInt];

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );
      request.fields['month'] = monthName;
      request.fields['year'] = year;
      request.fields['session_id'] = sessionId;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _pickedFile!.bytes!,
          filename: _pickedFile!.name,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DashboardScreen(sessionId: sessionId, month: month),
            ),
          );
        }
      } else {
        setState(() => _error = 'Upload failed: $body');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              _buildUploadZone(),
              const SizedBox(height: 24),
              _buildMonthField(),
              const SizedBox(height: 16),
              _buildHint(),
              const SizedBox(height: 32),
              if (_error != null) ...[
                _buildErrorBanner(),
                const SizedBox(height: 20),
              ],
              _buildUploadButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Orange accent bar
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: _orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Import Statement',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload your UOB eStatement PDF to get started.',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 14,
            color: _textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ─── Upload zone ──────────────────────────────────────────────────────────

  Widget _buildUploadZone() {
    final hasFile = _pickedFile != null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _uploadZonePressed = true),
      onTapUp: (_) {
        setState(() => _uploadZonePressed = false);
        if (!hasFile) _pickFile();
      },
      onTapCancel: () => setState(() => _uploadZonePressed = false),
      onTap: hasFile ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: _uploadZonePressed
              ? _surfaceElevated
              : (hasFile ? const Color(0xFF1A2A1A) : _surface),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasFile
                ? const Color(0xFF00C076).withOpacity(0.5)
                : (_uploadZonePressed ? _orange : _border),
            width: hasFile ? 1.5 : 1,
            // Dashed border via custom painter below
          ),
        ),
        child: hasFile ? _buildFileSelectedState() : _buildEmptyUploadState(),
      ),
    );
  }

  Widget _buildEmptyUploadState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated upload icon
        AnimatedBuilder(
          animation: _bounceAnim,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _bounceAnim.value),
            child: child,
          ),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: _orange,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tap to select your PDF',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'UOB eStatement · PDF only',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 12,
            color: _textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 20),
        // Pill hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _orange.withOpacity(0.2)),
          ),
          child: const Text(
            'Store PDF in Documents folder first',
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 11,
              color: _orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileSelectedState() {
    final sizeKb = ((_pickedFile!.size) / 1024).toStringAsFixed(1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Green checkmark circle
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF00C076).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF00C076),
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'File ready',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF00C076),
          ),
        ),
        const SizedBox(height: 8),
        // File name pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2F1F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00C076).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFF00C076),
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _pickedFile!.name,
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 12,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$sizeKb KB',
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 11,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Change file link
        GestureDetector(
          onTap: _pickFile,
          child: const Text(
            'Change file',
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              color: _textSecondary,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF888888),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Month field ──────────────────────────────────────────────────────────

Widget _buildMonthField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STATEMENT MONTH',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _monthController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 15,
            color: _textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
          decoration: InputDecoration(
            hintText: '2026 – 01',
            counterText: '', // hides the "0/6" character counter
            hintStyle: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 15,
              color: Color(0xFF444444),
              letterSpacing: 2,
            ),
            filled: true,
            fillColor: _surface,
            prefixIcon: const Icon(
              Icons.calendar_month_rounded,
              color: _textSecondary,
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _orange, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _errorRed),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Hint ─────────────────────────────────────────────────────────────────

  Widget _buildHint() {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: _textSecondary.withOpacity(0.6),
        ),
        const SizedBox(width: 6),
        const Text(
          'Type 6 digits — year then month, e.g. 202601 for Jan 2026',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 11,
            color: Color(0xFF555555),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─── Error banner ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 12,
                color: _errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Upload button ────────────────────────────────────────────────────────

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _upload,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          disabledBackgroundColor: _orange.withOpacity(0.3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_rounded, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Analyse Statement',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
