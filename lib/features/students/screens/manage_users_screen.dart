import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Single Entry Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'student';
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitSingle() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Email are required', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.warning));
      return;
    }
    
    setState(() => _isSubmitting = true);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'manage-users',
        body: {
          'action': 'bulk_create',
          'users': [
            {
              'name': _nameCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
              'role': _selectedRole,
              'password': _passwordCtrl.text.trim().isEmpty ? 'oracle2025' : _passwordCtrl.text.trim(),
            }
          ]
        }
      );
      
      if (res.status == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created successfully!', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.success));
          _nameCtrl.clear();
          _emailCtrl.clear();
          _phoneCtrl.clear();
          _passwordCtrl.clear();
        }
      } else {
        throw Exception('Failed to create user');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAndUploadCSV() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() => _isSubmitting = true);
      try {
        final csvString = utf8.decode(result.files.single.bytes!);
        List<List<dynamic>> rowsAsListOfValues = Csv().decode(csvString);
        
        if (rowsAsListOfValues.isEmpty) throw Exception('CSV is empty');
        
        // Assume first row is header
        final headers = rowsAsListOfValues[0].map((e) => e.toString().toLowerCase().trim()).toList();
        
        // Find indices
        final nameIdx = headers.indexOf('name');
        final emailIdx = headers.indexOf('email');
        final phoneIdx = headers.indexOf('phone');
        final roleIdx = headers.indexOf('role');
        final passIdx = headers.indexOf('password');
        
        if (nameIdx == -1 || emailIdx == -1) {
          throw Exception('CSV must contain "name" and "email" columns');
        }
        
        List<Map<String, dynamic>> usersPayload = [];
        
        for (int i = 1; i < rowsAsListOfValues.length; i++) {
          final row = rowsAsListOfValues[i];
          if (row.length <= nameIdx || row.length <= emailIdx) continue;
          
          final name = row[nameIdx].toString().trim();
          final email = row[emailIdx].toString().trim();
          if (name.isEmpty || email.isEmpty) continue;
          
          final phone = phoneIdx != -1 && row.length > phoneIdx ? row[phoneIdx].toString().trim() : '';
          
          // Role defaults to student
          String role = 'student';
          if (roleIdx != -1 && row.length > roleIdx) {
            final parsedRole = row[roleIdx].toString().toLowerCase().trim();
            if (parsedRole == 'parent' || parsedRole == 'student') {
              role = parsedRole;
            }
          }
          
          final password = passIdx != -1 && row.length > passIdx ? row[passIdx].toString().trim() : 'oracle2025';
          
          usersPayload.add({
            'name': name,
            'email': email,
            'phone': phone,
            'role': role,
            'password': password.isEmpty ? 'oracle2025' : password,
          });
        }
        
        if (usersPayload.isEmpty) throw Exception('No valid users found in CSV');
        
        final res = await Supabase.instance.client.functions.invoke(
          'manage-users',
          body: {
            'action': 'bulk_create',
            'users': usersPayload,
          }
        );
        
        if (res.status == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully created ${usersPayload.length} users!', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.success));
          }
        } else {
          throw Exception('Failed to create users');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error));
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OracleBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 12),
                    const Text('Manage Users', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.blobSky,
                labelColor: AppColors.blobSky,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: 'Single Entry'),
                  Tab(text: 'Bulk Import (CSV)'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSingleEntry(),
                    _buildBulkEntry(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add New User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                _buildTextField('Full Name', _nameCtrl, Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField('Email Address', _emailCtrl, Icons.email_outlined),
                const SizedBox(height: 16),
                _buildTextField('Phone Number', _phoneCtrl, Icons.phone_outlined),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  dropdownColor: AppColors.bg1,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.blobSky),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'parent', child: Text('Parent')),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
                const SizedBox(height: 16),
                _buildTextField('Password (Optional)', _passwordCtrl, Icons.lock_outline, obscureText: true),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blobSky,
                      foregroundColor: AppColors.bg0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _submitSingle,
                    child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg0))
                        : const Text('Create User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulkEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.upload_file, size: 64, color: AppColors.blobSky),
                const SizedBox(height: 24),
                const Text('Upload CSV File', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                const Text(
                  'Your CSV should have the following columns:\nname, email, phone (optional), role (student/parent), password (optional)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blobSky,
                      foregroundColor: AppColors.bg0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _pickAndUploadCSV,
                    icon: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg0))
                        : const Icon(Icons.file_open),
                    label: Text(_isSubmitting ? 'Processing...' : 'Select File', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.blobSky),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
