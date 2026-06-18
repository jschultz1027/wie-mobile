import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_menu_button.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/property.dart';
import '../../providers/auth_provider.dart';
import '../../services/zone_manager_service.dart';
import '../../widgets/property_risk_summary.dart';
import 'zone_manager_detail_screen.dart';

/// Zone Manager list: select a property to define zones.
/// Admin only. See docs/ZONE_MANAGER_LOGIC_FOR_FLUTTER.md.
class ZoneManagerListScreen extends StatefulWidget {
  const ZoneManagerListScreen({super.key});

  @override
  State<ZoneManagerListScreen> createState() => _ZoneManagerListScreenState();
}

class _ZoneManagerListScreenState extends State<ZoneManagerListScreen> {
  final ZoneManagerService _api = ZoneManagerService();
  final TextEditingController _searchController = TextEditingController();
  List<Property> _properties = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getPropertiesPaginated(
        page: _page,
        pageSize: 20,
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
      setState(() {
        _properties = reset ? res.items : [..._properties, ...res.items];
        _total = res.total;
        _totalPages = res.totalPages;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch() => _loadPage(reset: true);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null && !auth.user!.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: Text('Admin only')));
    }

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.slate900,
        elevation: 0,
        leading: const AppMenuButton(),
        title: const Text(
          'Zone Manager',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a Property',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a property to define zones and risk attributes.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or address',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _onSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _onSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            ),
          if (_error != null) const SizedBox(height: 8),
          Expanded(
            child: _loading && _properties.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _properties.isEmpty
                    ? const Center(child: Text('No properties found. Try a different search.'))
                    : RefreshIndicator(
                        onRefresh: () => _loadPage(reset: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _properties.length + (_page < _totalPages ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _properties.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: TextButton(
                                    onPressed: _loading ? null : () {
                                      _page++;
                                      _loadPage();
                                    },
                                    child: Text(_loading ? 'Loading...' : 'Load more'),
                                  ),
                                ),
                              );
                            }
                            final p = _properties[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ZoneManagerDetailScreen(property: p),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.blue600.withOpacity(0.2),
                                            child: const Icon(Icons.location_on, color: AppColors.blue600, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  p.address ?? '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right, color: Colors.grey),
                                        ],
                                      ),
                                      if (p.hasRiskData) PropertyRiskChips(property: p),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
