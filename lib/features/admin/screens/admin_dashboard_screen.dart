import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _organizations = [];

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

  Future<void> _fetchOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'organization')
          .order('created_at', ascending: false);
      setState(() {
        _organizations = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching organizations: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text('Admin Portal - Organizations'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.blobSky),
            onPressed: _fetchOrganizations,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.blobCoral),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: OracleBackground(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.blobSky))
            : _organizations.isEmpty 
                ? const Center(child: Text("No organizations found.", style: TextStyle(color: Colors.white, fontSize: 18)))
                : _buildOrgGrid(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOrgDialog,
        backgroundColor: AppColors.blobSky,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Organization", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOrgGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.5,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        final org = _organizations[index];
        return _buildOrgCard(org);
      },
    );
  }

  Widget _buildOrgCard(Map<String, dynamic> org) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showOrgDetails(org),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blobSky.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business, color: AppColors.blobSky),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org['full_name'] ?? 'Unknown Org',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          org['email'] ?? 'No email',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Divider(color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Phone: ${org['phone'] ?? 'N/A'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrgDetails(Map<String, dynamic> org) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bg1,
        title: Text(org['full_name'] ?? 'Org Details', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', org['email']),
            _buildDetailRow('Phone', org['phone']),
            _buildDetailRow('Created', org['created_at'].toString().split('T').first),
            _buildDetailRow('ID', org['id']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.blobSky)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value?.toString() ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  void _showAddOrgDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passkeyCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.bg1,
            title: const Text('New Organization', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Organization Name', labelStyle: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Admin Email', labelStyle: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passkeyCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Passkey / Password', labelStyle: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.blobSky),
                onPressed: isSubmitting ? null : () async {
                  if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                  
                  setState(() => isSubmitting = true);
                  try {
                    final res = await Supabase.instance.client.functions.invoke(
                      'manage-users',
                      body: {
                        'action': 'bulk_create',
                        'users': [
                          {
                            'full_name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'role': 'organization',
                            'password': passkeyCtrl.text.trim().isEmpty ? 'oracle2025' : passkeyCtrl.text.trim(),
                          }
                        ]
                      }
                    );
                    
                    if (res.status == 200) {
                      if (context.mounted) Navigator.pop(context);
                      _fetchOrganizations();
                    } else {
                      throw Exception('Failed to create organization');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                    setState(() => isSubmitting = false);
                  }
                },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
}
