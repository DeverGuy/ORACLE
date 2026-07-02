import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/config/supabase_config.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _users = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching users: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _uploadCsv() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.csv';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        
        reader.onLoadEnd.listen((e) async {
          setState(() => _isLoading = true);
          try {
            final csvString = reader.result as String;
            
            // Basic CSV parser
            final lines = csvString.split('\n').where((l) => l.trim().isNotEmpty).toList();
            if (lines.length <= 1) throw Exception("CSV file appears to be empty or only contains headers.");

            final headers = lines.first.split(',').map((e) => e.trim().toLowerCase()).toList();
            final usersToCreate = [];

            for (var i = 1; i < lines.length; i++) {
              final parts = lines[i].split(',').map((e) => e.trim()).toList();
              if (parts.isEmpty) continue;

              final user = <String, dynamic>{};
              for (var j = 0; j < headers.length; j++) {
                if (j < parts.length) {
                  user[headers[j]] = parts[j];
                }
              }
              usersToCreate.add(user);
            }

            // Call Edge Function
            final response = await Supabase.instance.client.functions.invoke(
              'manage-users',
              body: {
                'action': 'bulk_create',
                'users': usersToCreate,
              },
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bulk upload processed successfully!')),
              );
              _fetchUsers();
            }
          } catch (err) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $err')));
            }
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        });
        
        reader.readAsText(file);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadCsv,
            tooltip: 'Bulk Upload CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  color: AppColors.bg2,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(user['full_name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${user['email']} • Role: ${user['role']}', style: const TextStyle(color: Colors.white70)),
                    trailing: const Icon(Icons.edit, color: Colors.white54),
                  ),
                );
              },
            ),
    );
  }
}
