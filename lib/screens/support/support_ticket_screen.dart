import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_notification.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import '../../config/help_content.dart';
import '../../widgets/tap_tooltip.dart';

/// Support ticket center for clients and contractors. Matches web /support-ticket.
class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'general';
  String _priority = 'medium';
  String? _propertyId;
  bool _submitting = false;

  // Example tickets — same demo data as web until backend is wired.
  late List<_SupportTicket> _tickets;

  static const _categories = <String, String>{
    'general': 'General Question',
    'service-issue': 'Service Issue',
    'service-request': 'Service Request',
    'billing': 'Billing',
    'contract': 'Contract Question',
    'documentation': 'Documentation Request',
    'technical': 'Technical Support',
  };

  static const _properties = <String, String>{
    '1': '2927 Fremont Street',
    '2': '715 Ducklow Street',
    '3': '3402-3474 Copeland Avenue',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tickets = _mockTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<_SupportTicket> _mockTickets() {
    return [
      _SupportTicket(
        id: 1,
        subject: 'Snow removal not completed on parking area',
        category: 'Service Issue',
        priority: 'high',
        status: 'in-progress',
        createdAt: DateTime(2026, 1, 6, 8, 30),
        updatedAt: DateTime(2026, 1, 6, 10, 15),
        description:
            "The parking area at 2927 Fremont Street was not fully cleared after yesterday's snowfall. About 30% of the parking spots still have snow.",
        assignedTo: 'Sarah Johnson',
        repliesCount: 3,
      ),
      _SupportTicket(
        id: 2,
        subject: 'Request for additional salt application',
        category: 'Service Request',
        priority: 'medium',
        status: 'waiting-response',
        createdAt: DateTime(2026, 1, 5, 14, 20),
        updatedAt: DateTime(2026, 1, 5, 16, 45),
        description:
            'We noticed ice forming on the walkways at 715 Ducklow Street. Could we get an additional salt application today?',
        assignedTo: 'Sarah Johnson',
        repliesCount: 2,
      ),
      _SupportTicket(
        id: 3,
        subject: 'Billing question about December invoice',
        category: 'Billing',
        priority: 'low',
        status: 'resolved',
        createdAt: DateTime(2026, 1, 3, 11),
        updatedAt: DateTime(2026, 1, 4, 9, 30),
        description:
            'I have a question about the December invoice. It shows 12 service calls but I only recall 10. Can you provide details?',
        assignedTo: 'Finance Team',
        repliesCount: 4,
      ),
      _SupportTicket(
        id: 4,
        subject: 'Request for service report photos',
        category: 'Documentation',
        priority: 'low',
        status: 'closed',
        createdAt: DateTime(2025, 12, 28, 9, 15),
        updatedAt: DateTime(2025, 12, 28, 14, 20),
        description:
            'Can you please send me the photos from the December 27th service at Copeland Avenue?',
        assignedTo: 'Operations Team',
        repliesCount: 2,
      ),
    ];
  }

  Future<void> _launchUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitTicket() async {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();
    if (subject.isEmpty || description.isEmpty) {
      AppNotification.error(context, 'Please fill in all required fields.');
      return;
    }

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _submitting = false);

    AppNotification.success(
      context,
      'Ticket submitted. Our team will respond soon.',
    );

    _subjectController.clear();
    _descriptionController.clear();
    setState(() {
      _category = 'general';
      _priority = 'medium';
      _propertyId = null;
    });
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user != null && user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: AppColors.slate900,
          leading: const AppMenuButton(),
          title: const Text('Support Ticket', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: Text('Support tickets are for clients and contractors.')),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Support Center',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          ScreenHelpAction(
            title: 'Support Center',
            message: HelpContent.screenSupportTicket,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.blue500,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'New Ticket'),
            Tab(text: 'My Tickets (${_tickets.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewTicketTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  Widget _buildNewTicketTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildContactBanner(),
          const SizedBox(height: 16),
          _buildDropdown(
            label: 'Category *',
            help: HelpContent.supportCategory,
            value: _category,
            items: _categories.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Priority *',
            help: HelpContent.supportPriority,
            value: _priority,
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low - General inquiry')),
              DropdownMenuItem(value: 'medium', child: Text('Medium - Non-urgent issue')),
              DropdownMenuItem(value: 'high', child: Text('High - Affecting service')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgent - Critical issue')),
            ],
            onChanged: (v) => setState(() => _priority = v ?? 'medium'),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Subject *',
            help: HelpContent.supportSubject,
            controller: _subjectController,
            hint: 'Brief description of your issue or request',
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Related Property (optional)',
            help: HelpContent.supportProperty,
            value: _propertyId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Select a property (optional)')),
              ..._properties.entries.map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
            onChanged: (v) => setState(() => _propertyId = v),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            label: 'Description *',
            help: HelpContent.supportDescription,
            controller: _descriptionController,
            hint: 'Provide details about your issue or request.',
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file, color: Colors.grey.shade500),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Attach Files (Coming Soon)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TapTooltip(
            title: 'Submit Ticket',
            message: HelpContent.supportSubmit,
            triggerOnLongPressOnly: true,
            child: FilledButton.icon(
            onPressed: _submitting ? null : _submitTicket,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(_submitting ? 'Submitting...' : 'Submit Ticket'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue600,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTicketsTab() {
    if (_tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No Tickets Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                "You haven't submitted any support tickets.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _tabController.animateTo(0),
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue600),
                child: const Text('Create Your First Ticket'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildTicketCard(_tickets[index]),
    );
  }

  Widget _buildContactBanner() {
    return TapTooltip(
      title: 'Immediate assistance',
      message: HelpContent.supportContactBanner,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need Immediate Assistance?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
          ),
          const SizedBox(height: 8),
          Text('Account Manager: Sarah Johnson', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          InkWell(
            onTap: () => _launchUri(Uri.parse('tel:+16045550123')),
            child: Text(
              'Phone: (604) 555-0123',
              style: TextStyle(fontSize: 13, color: AppColors.blue600),
            ),
          ),
          InkWell(
            onTap: () => _launchUri(Uri.parse('mailto:sarah.johnson@winterintelligence.com')),
            child: Text(
              'Email: sarah.johnson@winterintelligence.com',
              style: TextStyle(fontSize: 13, color: AppColors.blue600),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '24/7 Emergency: (604) 555-SNOW (7669)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Office Hours: Mon–Fri 8am–6pm · Sat–Sun 9am–4pm',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
    String? help,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        help != null
            ? HelpLabel(
                label: label,
                help: help,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              )
            : Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        const SizedBox(height: 6),
        TapTooltip(
          title: label,
          message: help ?? label,
          triggerOnLongPressOnly: true,
          child: DropdownButtonFormField<String?>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? help,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        help != null
            ? HelpLabel(
                label: label,
                help: help,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              )
            : Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        const SizedBox(height: 6),
        TapTooltip(
          title: label,
          message: help ?? label,
          triggerOnLongPressOnly: true,
          child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(_SupportTicket ticket) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTicketDetail(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '#${ticket.id}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(ticket.statusLabel, _statusColor(ticket.status)),
                  _chip(ticket.priority.toUpperCase(), _priorityColor(ticket.priority)),
                  _chip(ticket.category, Colors.grey.shade700),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (ticket.assignedTo != null)
                    Expanded(
                      child: Text(
                        'Assigned: ${ticket.assignedTo}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  Text(
                    '${ticket.repliesCount} replies',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.blue600;
      case 'in-progress':
        return Colors.purple;
      case 'waiting-response':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.blue600;
    }
  }

  void _showTicketDetail(_SupportTicket ticket) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ticket.subject,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Ticket #${ticket.id}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(ticket.statusLabel, _statusColor(ticket.status)),
                  _chip(ticket.priority.toUpperCase(), _priorityColor(ticket.priority)),
                  _chip(ticket.category, Colors.grey.shade700),
                ],
              ),
              const SizedBox(height: 16),
              Text(ticket.description, style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.5)),
              if (ticket.assignedTo != null) ...[
                const SizedBox(height: 16),
                Text('Assigned to: ${ticket.assignedTo}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
              const SizedBox(height: 8),
              Text(
                'Created ${_formatDate(ticket.createdAt)} · Updated ${_formatDate(ticket.updatedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _SupportTicket {
  const _SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.description,
    this.assignedTo,
    this.repliesCount = 0,
  });

  final int id;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;
  final String? assignedTo;
  final int repliesCount;

  String get statusLabel => status.replaceAll('-', ' ').toUpperCase();
}
