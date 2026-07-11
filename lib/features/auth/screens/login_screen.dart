import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String portalType; // 'admin', 'org', or 'portal'
  const LoginScreen({super.key, required this.portalType});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;
  String? _error;
  bool _obscurePass = true;
  String _selectedRole = 'Student'; // Default for the portal type
  
  final List<String> _portalRoles = ['Student', 'Parent'];

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      String email = _emailController.text.trim();
      
      // Custom mapping for the requested Admin username
      if (email == 'ORACLE (MPBA)') {
        email = 'admin@oracle.mpba.com';
      }

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text.trim(),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'An unexpected error occurred with Google Sign-in.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OracleBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / brand
                  _buildBrand()
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .slideY(begin: -0.2),
                  const SizedBox(height: 40),

                  // Login card
                  GlassCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome back',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.portalType == 'admin' 
                            ? 'Sign in to Admin Portal'
                            : widget.portalType == 'org'
                                ? 'Sign in to Organization Portal'
                                : 'Sign in to Student & Parent Portal',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        
                        // Role Selection (Only for Student/Parent portal)
                        if (widget.portalType == 'portal') ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _portalRoles.map((role) {
                              final isSelected = _selectedRole == role;
                              return ChoiceChip(
                                label: Text(role),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedRole = role);
                                  }
                                },
                                selectedColor: AppColors.blobSky.withOpacity(0.2),
                                backgroundColor: AppColors.bg3,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.blobSky : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected ? AppColors.blobSky : Colors.transparent,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Email
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePass,
                          style: const TextStyle(color: AppColors.textPrimary),
                          onSubmitted: (_) => _signIn(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        
                        // Remember Me Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                              activeColor: AppColors.blobSky,
                              side: const BorderSide(color: AppColors.textSecondary),
                            ),
                            const Text('Remember Me', style: TextStyle(color: AppColors.textPrimary)),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Sign In button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signIn,
                            child: _loading
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg0),
                                  )
                                : const Text('Sign In', style: TextStyle(fontSize: 16)),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          children: const [
                            Expanded(child: Divider(color: AppColors.bg3)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            Expanded(child: Divider(color: AppColors.bg3)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Button
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _signInWithGoogle,
                            icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.white),
                            label: const Text('Continue with Google', style: TextStyle(color: Colors.white, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.bg3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Apple Button
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: Implement Apple OAuth
                            },
                            icon: const Icon(Icons.apple, size: 28, color: Colors.white),
                            label: const Text('Continue with Apple', style: TextStyle(color: Colors.white, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.bg3),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        // Demo hint
                        Center(
                          child: Text(
                            'Demo: admin@oracle.school / oracle2025',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 700.ms, delay: 300.ms)
                      .slideY(begin: 0.1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppGradients.accentCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.blobSky.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'O',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ORACLE',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'School Fee Management System',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
