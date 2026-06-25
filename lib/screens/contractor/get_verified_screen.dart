import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../models/get_verified.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/get_verified_service.dart';
import '../../utils/image_compression.dart';
import '../../utils/picker_file.dart';
import '../../utils/app_notification.dart';
import '../auth/login_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// Contractor Get Verified. Matches web: /get-verified.
/// Insurance, Driver's License (front + back), 2 References, Void Cheque.
/// Approved sections are hidden; rejected items show reason and Replace & re-submit.
class GetVerifiedScreen extends StatefulWidget {
  const GetVerifiedScreen({super.key});

  @override
  State<GetVerifiedScreen> createState() => _GetVerifiedScreenState();
}

class _GetVerifiedScreenState extends State<GetVerifiedScreen> {
  final GetVerifiedService _service = GetVerifiedService();
  final ImagePicker _picker = ImagePicker();

  List<VerificationItem> _verifications = [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;

  File? _insuranceFile;
  File? _licenseFrontFile;
  File? _licenseBackFile;
  File? _voidChequeFile;

  final _refName = [TextEditingController(), TextEditingController()];
  final _refCompany = [TextEditingController(), TextEditingController()];
  final _refPhone = [TextEditingController(), TextEditingController()];
  final _refEmail = [TextEditingController(), TextEditingController()];
  final _refRelationship = [TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _refName) c.dispose();
    for (final c in _refCompany) c.dispose();
    for (final c in _refPhone) c.dispose();
    for (final c in _refEmail) c.dispose();
    for (final c in _refRelationship) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = StorageService().getToken();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (token == null || user == null) {
      if (mounted) _handleSessionExpired();
      return;
    }
    if (user.role != 'contractor') {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.getVerifications();
      if (mounted) {
        _populateReferencesFromList(list);
        setState(() { _verifications = list; _loading = false; });
      }
    } on GetVerifiedException catch (e) {
      if (e.isUnauthorized && mounted) { _handleSessionExpired(); return; }
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _populateReferencesFromList(List<VerificationItem> list) {
    for (final v in list) {
      if (v.verificationType == 'reference_1' && v.referenceName != null) {
        _refName[0].text = v.referenceName!;
        _refCompany[0].text = v.referenceCompany ?? '';
        _refPhone[0].text = v.referencePhone ?? '';
        _refEmail[0].text = v.referenceEmail ?? '';
        _refRelationship[0].text = v.referenceRelationship ?? '';
      } else if (v.verificationType == 'reference_2' && v.referenceName != null) {
        _refName[1].text = v.referenceName!;
        _refCompany[1].text = v.referenceCompany ?? '';
        _refPhone[1].text = v.referencePhone ?? '';
        _refEmail[1].text = v.referenceEmail ?? '';
        _refRelationship[1].text = v.referenceRelationship ?? '';
      }
    }
  }

  Future<void> _handleSessionExpired() async {
    await StorageService().clearAll();
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  VerificationItem? _byType(String type) {
    try {
      return _verifications.firstWhere((v) => v.verificationType == type);
    } catch (_) {
      return null;
    }
  }

  String _statusFor(String type) {
    final v = _byType(type);
    if (v == null) return 'missing';
    return v.status;
  }

  /// References: approved only when both ref_1 and ref_2 are approved
  String get _referencesStatus {
    final r1 = _byType('reference_1');
    final r2 = _byType('reference_2');
    if (r1 == null && r2 == null) return 'missing';
    if (r1?.status == 'rejected' || r2?.status == 'rejected') return 'rejected';
    if (r1 != null && r2 != null && r1.status == 'approved' && r2.status == 'approved') return 'approved';
    return 'pending';
  }

  int get _progressCount {
    int n = 0;
    if (_statusFor('insurance') == 'approved' || _statusFor('insurance') == 'pending') n++;
    if (_statusFor('driver_license_front') == 'approved' || _statusFor('driver_license_front') == 'pending') n++;
    if (_statusFor('driver_license_back') == 'approved' || _statusFor('driver_license_back') == 'pending') n++;
    if (_referencesStatus == 'approved' || _referencesStatus == 'pending') n++;
    if (_statusFor('void_cheque') == 'approved' || _statusFor('void_cheque') == 'pending') n++;
    return n;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppColors.success;
      case 'pending': return AppColors.warning;
      case 'rejected': return AppColors.error;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'pending': return Icons.schedule;
      case 'rejected': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  Future<void> _pickImage(ValueChanged<File?> setFile) async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x != null) {
        final compressed = await ImageCompression.compressXFile(x);
        setState(() => setFile(compressed));
      }
    } catch (_) {}
  }

  Future<void> _pickDocumentOrImage(ValueChanged<File?> setFile) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = await PickerFileUtil.toLocalFile(
        result.files.single,
        prefix: 'verification_doc',
      );

      if (ImageCompression.isPdfPath(file.path)) {
        setState(() => setFile(file));
        return;
      }
      final compressed = await ImageCompression.compressPhotoFile(file);
      setState(() => setFile(compressed));
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Could not select file: $e');
    }
  }

  Future<void> _pickVoidChequeFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = await PickerFileUtil.toLocalFile(
        result.files.single,
        prefix: 'void_cheque',
      );

      if (ImageCompression.isPdfPath(file.path)) {
        setState(() => _voidChequeFile = file);
        return;
      }
      final compressed = await ImageCompression.compressPhotoFile(file);
      setState(() => _voidChequeFile = compressed);
    } catch (e) {
      if (mounted) AppNotification.error(context, 'Could not select file: $e');
    }
  }

  Future<int> _verificationIdForUpload(String type, {VerificationItem? existing}) async {
    if (existing != null &&
        (existing.status == 'rejected' || existing.status == 'pending')) {
      return existing.id;
    }
    final created = await _service.submitVerification(verificationType: type);
    return created.id;
  }

  Future<void> _openDocumentUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppNotification.error(context, 'Could not open document');
    }
  }

  String? _formatUploadDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateFormat.yMMMd().add_jm().format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitInsurance() async {
    if (_insuranceFile == null) {
      AppNotification.warning(context, 'Please select a file');
      return;
    }
    setState(() => _uploading = true);
    try {
      final id = await _verificationIdForUpload(
        'insurance',
        existing: _byType('insurance'),
      );
      final result = await _service.uploadDocument(id, _insuranceFile!);
      if (mounted) {
        await _load();
        final name = result.documentName ?? 'Insurance document';
        AppNotification.success(context, '$name saved to your profile. Pending review.');
      }
    } on GetVerifiedException catch (e) {
      if (mounted) AppNotification.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
    }
    if (mounted) setState(() { _uploading = false; _insuranceFile = null; });
  }

  Future<void> _submitDriverLicense() async {
    final needFront = _statusFor('driver_license_front') == 'missing' || _statusFor('driver_license_front') == 'rejected';
    final needBack = _statusFor('driver_license_back') == 'missing' || _statusFor('driver_license_back') == 'rejected';
    final hasFront = needFront && _licenseFrontFile != null;
    final hasBack = needBack && _licenseBackFile != null;
    if (!hasFront && !hasBack) {
      AppNotification.warning(context, 'Please upload the front and/or back of your driver license as needed.');
      return;
    }
    setState(() => _uploading = true);
    try {
      if (hasFront) {
        final id = await _verificationIdForUpload(
          'driver_license_front',
          existing: _byType('driver_license_front'),
        );
        await _service.uploadDocument(id, _licenseFrontFile!);
      }
      if (hasBack) {
        final id = await _verificationIdForUpload(
          'driver_license_back',
          existing: _byType('driver_license_back'),
        );
        await _service.uploadDocument(id, _licenseBackFile!);
      }
      if (mounted) {
        await _load();
        AppNotification.success(context, 'Driver\'s license saved to your profile. Pending review.');
      }
    } on GetVerifiedException catch (e) {
      if (mounted) AppNotification.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
    }
    if (mounted) setState(() { _uploading = false; _licenseFrontFile = null; _licenseBackFile = null; });
  }

  Future<void> _submitReferences() async {
    final ref0 = _refName[0].text.trim().isNotEmpty && _refCompany[0].text.trim().isNotEmpty &&
        _refPhone[0].text.trim().isNotEmpty && _refEmail[0].text.trim().isNotEmpty &&
        _refRelationship[0].text.trim().isNotEmpty;
    final ref1 = _refName[1].text.trim().isNotEmpty && _refCompany[1].text.trim().isNotEmpty &&
        _refPhone[1].text.trim().isNotEmpty && _refEmail[1].text.trim().isNotEmpty &&
        _refRelationship[1].text.trim().isNotEmpty;
    if (!ref0 || !ref1) {
      AppNotification.warning(context, 'Please complete both references');
      return;
    }
    setState(() => _uploading = true);
    try {
      await _service.submitVerification(
        verificationType: 'reference_1',
        referenceName: _refName[0].text.trim(),
        referenceCompany: _refCompany[0].text.trim(),
        referencePhone: _refPhone[0].text.trim(),
        referenceEmail: _refEmail[0].text.trim(),
        referenceRelationship: _refRelationship[0].text.trim(),
      );
      await _service.submitVerification(
        verificationType: 'reference_2',
        referenceName: _refName[1].text.trim(),
        referenceCompany: _refCompany[1].text.trim(),
        referencePhone: _refPhone[1].text.trim(),
        referenceEmail: _refEmail[1].text.trim(),
        referenceRelationship: _refRelationship[1].text.trim(),
      );
      if (mounted) {
        await _load();
        AppNotification.success(context, 'References submitted. They may be contacted within 3–5 business days.');
      }
    } on GetVerifiedException catch (e) {
      if (mounted) AppNotification.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _submitVoidCheque() async {
    if (_voidChequeFile == null) {
      AppNotification.warning(context, 'Please select a file');
      return;
    }
    setState(() => _uploading = true);
    try {
      var v = _byType('void_cheque');
      final id = await _verificationIdForUpload('void_cheque', existing: v);
      final result = await _service.uploadDocument(id, _voidChequeFile!);
      if (mounted) {
        await _load();
        final name = result.documentName ?? 'Void cheque';
        AppNotification.success(context, '$name saved to your profile. Pending review.');
      }
    } on GetVerifiedException catch (e) {
      if (mounted) AppNotification.error(context, e.message);
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
    }
    if (mounted) setState(() { _uploading = false; _voidChequeFile = null; });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progressCount;
    final insuranceStatus = _statusFor('insurance');
    final licenseFrontStatus = _statusFor('driver_license_front');
    final licenseBackStatus = _statusFor('driver_license_back');
    final referencesStatus = _referencesStatus;
    final voidChequeStatus = _statusFor('void_cheque');

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Get Verified',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          ScreenHelpAction(
            title: 'Get Verified',
            message: HelpContent.screenGetVerified,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _verifications.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.blue600),
                    ),
                    SizedBox(height: 16),
                    Text('Loading verification…', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              )
            : _error != null && _verifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Retry'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue600,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        const SizedBox(height: 28),
                        _buildProgressCard(progress),
                        const SizedBox(height: 28),
                        if (insuranceStatus != 'approved') _buildInsuranceSection(insuranceStatus),
                        if (insuranceStatus != 'approved') const SizedBox(height: 16),
                        if (licenseFrontStatus != 'approved' || licenseBackStatus != 'approved')
                          _buildDriverLicenseSection(licenseFrontStatus, licenseBackStatus),
                        if (licenseFrontStatus != 'approved' || licenseBackStatus != 'approved') const SizedBox(height: 16),
                        if (referencesStatus != 'approved') _buildReferencesSection(referencesStatus),
                        if (referencesStatus != 'approved') const SizedBox(height: 16),
                        if (voidChequeStatus != 'approved') _buildVoidChequeSection(voidChequeStatus),
                        if (voidChequeStatus != 'approved') const SizedBox(height: 16),
                        const SizedBox(height: 28),
                        _buildHelpCard(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blue600.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.verified_user_outlined, color: AppColors.blue600, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          'Get Verified',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload insurance, driver\'s license (front and back), 2 references, and a void cheque. Documents are stored securely.',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(int progress) {
    final labels = ['Insurance', 'License Front', 'License Back', 'References', 'Void Cheque'];
    final statuses = [
      _statusFor('insurance'),
      _statusFor('driver_license_front'),
      _statusFor('driver_license_back'),
      _referencesStatus,
      _statusFor('void_cheque'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification progress',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$progress',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue600,
                  height: 1,
                ),
              ),
              Text(
                ' / 5 complete',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress / 5,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue600),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(5, (i) {
              return _statusChip(labels[i], statuses[i]);
            }),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ${status.toUpperCase()}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedDocumentCard(VerificationItem? item, {String? pendingLabel}) {
    if (item == null || !item.hasUploadedDocument) return const SizedBox.shrink();

    final uploadedAt = _formatUploadDate(item.updatedAt ?? item.createdAt);
    final fileName = item.documentName ?? item.displayType;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pendingLabel ?? 'Saved to your profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileName,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    if (uploadedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Uploaded $uploadedAt',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                    if (item.status == 'pending') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Status: Pending review',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.warning),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.isImageDocument) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.documentUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ] else if (item.isPdfDocument) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.picture_as_pdf, color: AppColors.error, size: 28),
                const SizedBox(width: 8),
                Text('PDF document', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openDocumentUrl(item.documentUrl!),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('View document'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue600,
              side: BorderSide(color: AppColors.blue600.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferencesSavedCard() {
    if (_referencesStatus != 'pending' && _referencesStatus != 'approved') {
      return const SizedBox.shrink();
    }

    final r1 = _byType('reference_1');
    final r2 = _byType('reference_2');
    if (r1?.referenceName == null || r2?.referenceName == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _referencesStatus == 'approved'
                      ? 'References approved'
                      : 'References saved to your profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _referenceSummaryLine('Reference 1', r1!),
          const SizedBox(height: 8),
          _referenceSummaryLine('Reference 2', r2!),
          if (_referencesStatus == 'pending') ...[
            const SizedBox(height: 8),
            Text(
              'Status: Pending review',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _referenceSummaryLine(String label, VerificationItem ref) {
    return Text(
      '$label: ${ref.referenceName} · ${ref.referenceCompany ?? ''}',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
    );
  }

  Widget _buildRejectionBanner(String? reason) {
    if (reason == null || reason.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reason rejected: $reason',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceSection(String status) {
    final statusColor = _statusColor(status);
    final v = _byType('insurance');
    final fileLabel = _insuranceFile != null ? _insuranceFile!.path.split(RegExp(r'[/\\]')).last : null;
    final hasSaved = v?.hasUploadedDocument == true;
    final showSubmit = (_insuranceFile != null) && (status == 'missing' || status == 'rejected' || status == 'pending');
    final showPicker = status != 'approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Insurance', 'Certificate of insurance (e.g. general liability)', status, statusColor, Icons.description_outlined),
          const SizedBox(height: 20),
          if (hasSaved) _buildSavedDocumentCard(v, pendingLabel: status == 'pending' ? 'Upload complete — saved to your profile' : null),
          if (showPicker || !hasSaved) ...[
            if (hasSaved && status == 'pending')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Replace document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              ),
            _filePicker(
              fileLabel,
              () => _pickDocumentOrImage((f) => setState(() => _insuranceFile = f)),
              () => setState(() => _insuranceFile = null),
            ),
          ],
          _buildRejectionBanner(v?.rejectionReason),
          if (showSubmit) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _submitInsurance,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_uploading ? 'Uploading…' : status == 'rejected' ? 'Replace & re-submit Insurance' : hasSaved ? 'Update Insurance Document' : 'Submit Insurance'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverLicenseSection(String frontStatus, String backStatus) {
    final statusColor = _statusColor(frontStatus == 'approved' && backStatus == 'approved' ? 'approved' : (frontStatus == 'rejected' || backStatus == 'rejected') ? 'rejected' : 'pending');
    final vFront = _byType('driver_license_front');
    final vBack = _byType('driver_license_back');
    final frontLabel = _licenseFrontFile != null ? _licenseFrontFile!.path.split(RegExp(r'[/\\]')).last : null;
    final backLabel = _licenseBackFile != null ? _licenseBackFile!.path.split(RegExp(r'[/\\]')).last : null;
    final hasFrontSaved = vFront?.hasUploadedDocument == true;
    final hasBackSaved = vBack?.hasUploadedDocument == true;
    final needFront = frontStatus == 'missing' || frontStatus == 'rejected';
    final needBack = backStatus == 'missing' || backStatus == 'rejected';
    final hasFrontFile = _licenseFrontFile != null && (needFront || frontStatus == 'pending');
    final hasBackFile = _licenseBackFile != null && (needBack || backStatus == 'pending');
    final showSubmit = hasFrontFile || hasBackFile;
    final showFrontPicker = frontStatus != 'approved';
    final showBackPicker = backStatus != 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Driver\'s License', 'Front and back of your driver\'s license', frontStatus == 'approved' && backStatus == 'approved' ? 'approved' : (frontStatus == 'rejected' || backStatus == 'rejected') ? 'rejected' : 'pending', statusColor, Icons.badge_outlined),
          const SizedBox(height: 20),
          if (hasFrontSaved) _buildSavedDocumentCard(vFront, pendingLabel: 'Front — saved to your profile'),
          if (hasBackSaved) _buildSavedDocumentCard(vBack, pendingLabel: 'Back — saved to your profile'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Front', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    if (showFrontPicker || !hasFrontSaved)
                      _filePickerSmall(frontLabel, () => _pickImage((f) => setState(() => _licenseFrontFile = f)), () => setState(() => _licenseFrontFile = null))
                    else if (frontStatus == 'pending')
                      Text('Under review', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    if (showBackPicker || !hasBackSaved)
                      _filePickerSmall(backLabel, () => _pickImage((f) => setState(() => _licenseBackFile = f)), () => setState(() => _licenseBackFile = null))
                    else if (backStatus == 'pending')
                      Text('Under review', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          _buildRejectionBanner(vFront?.rejectionReason ?? vBack?.rejectionReason),
          if (showSubmit) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _submitDriverLicense,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_uploading ? 'Uploading…' : (frontStatus == 'rejected' || backStatus == 'rejected') ? 'Replace & re-submit Driver License' : 'Submit Driver License'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReferencesSection(String status) {
    final statusColor = _statusColor(status);
    final readOnly = status == 'pending' || status == 'approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('2 References', 'From prior jobs or clients', status, statusColor, Icons.people_outline),
          const SizedBox(height: 20),
          _buildReferencesSavedCard(),
          _buildReferenceBlock(1, _refName[0], _refCompany[0], _refPhone[0], _refEmail[0], _refRelationship[0], readOnly: readOnly),
          const SizedBox(height: 16),
          _buildReferenceBlock(2, _refName[1], _refCompany[1], _refPhone[1], _refEmail[1], _refRelationship[1], readOnly: readOnly),
          if (status == 'missing' || status == 'rejected') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _submitReferences,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_uploading ? 'Submitting…' : status == 'rejected' ? 'Update & re-submit References' : 'Submit References'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoidChequeSection(String status) {
    final statusColor = _statusColor(status);
    final v = _byType('void_cheque');
    final fileLabel = _voidChequeFile != null ? _voidChequeFile!.path.split(RegExp(r'[/\\]')).last : null;
    final showSubmit = (_voidChequeFile != null) && (status == 'missing' || status == 'rejected' || status == 'pending');
    final showPicker = status != 'approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Void Cheque', 'For payments. PDF or image.', status, statusColor, Icons.account_balance_outlined),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blue600.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue600.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.blue600, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Documents are stored securely on AWS S3.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (v?.hasUploadedDocument == true)
            _buildSavedDocumentCard(v, pendingLabel: status == 'pending' ? 'Upload complete — saved to your profile' : null),
          if (showPicker) ...[
            if (v?.hasUploadedDocument == true && status == 'pending')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Replace document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              ),
            _filePicker(fileLabel, _pickVoidChequeFile, () => setState(() => _voidChequeFile = null)),
          ],
          _buildRejectionBanner(v?.rejectionReason),
          if (showSubmit) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _submitVoidCheque,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_uploading ? 'Uploading…' : status == 'rejected' ? 'Replace & re-submit Void Cheque' : v?.hasUploadedDocument == true ? 'Update Void Cheque' : 'Upload Void Cheque'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, String status, Color statusColor, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blue600.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.blue600, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.4)),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _filePicker(String? fileLabel, VoidCallback onPick, VoidCallback onRemove) {
    return InkWell(
      onTap: fileLabel == null ? onPick : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: fileLabel == null
            ? Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 44, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('Tap to choose file', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('PDF or image, max 10 MB', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.insert_drive_file, color: AppColors.success, size: 40),
                  const SizedBox(height: 10),
                  Text(fileLabel, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  TextButton.icon(onPressed: onRemove, icon: const Icon(Icons.close, size: 18), label: const Text('Remove')),
                ],
              ),
      ),
    );
  }

  Widget _filePickerSmall(String? fileLabel, VoidCallback onPick, VoidCallback onRemove) {
    return InkWell(
      onTap: fileLabel == null ? onPick : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: fileLabel == null
            ? Column(
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey.shade500),
                  const SizedBox(height: 6),
                  Text('Add', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.insert_drive_file, color: AppColors.success, size: 24),
                  const SizedBox(height: 4),
                  Text(fileLabel, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, maxLines: 1),
                  TextButton(onPressed: onRemove, child: const Text('Remove', style: TextStyle(fontSize: 11))),
                ],
              ),
      ),
    );
  }

  Widget _buildReferenceBlock(
    int index,
    TextEditingController name,
    TextEditingController company,
    TextEditingController phone,
    TextEditingController email,
    TextEditingController relationship, {
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reference $index', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          _field('Name', name, readOnly: readOnly),
          _field('Company', company, readOnly: readOnly),
          _field('Phone', phone, readOnly: readOnly),
          _field('Email', email, readOnly: readOnly),
          _field('Relationship', relationship, readOnly: readOnly),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.blue600, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 15),
        keyboardType: label.contains('Email') ? TextInputType.emailAddress : (label.contains('Phone') ? TextInputType.phone : TextInputType.text),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 22, color: AppColors.blue600),
              const SizedBox(width: 10),
              Text(
                'Need help?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Questions about verification? Contact support:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 6),
          SelectableText(
            'verification@winterimp.com  ·  (604) 555-SNOW',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.blue600),
          ),
        ],
      ),
    );
  }
}
