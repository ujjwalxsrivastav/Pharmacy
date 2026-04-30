import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@pharma.com');
  final _passCtrl = TextEditingController(text: 'password123');
  bool _obscure = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.primaryGradient), borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 24),
                Text('PharmaDash', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: colors.textPrimary)),
                const SizedBox(height: 8),
                Text('Sign in to manage your pharmacy', style: GoogleFonts.inter(fontSize: 14, color: colors.textSecondary)),
                const SizedBox(height: 40),
                Text('Email', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                const SizedBox(height: 8),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: GoogleFonts.inter(color: colors.textPrimary), decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined), hintText: 'admin@pharma.com')),
                const SizedBox(height: 16),
                Text('Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl, obscureText: _obscure, style: GoogleFonts.inter(color: colors.textPrimary),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_outlined), hintText: '••••••••', suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscure = !_obscure))),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Sign In', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signIn(_emailCtrl.text.trim(), _passCtrl.text.trim());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
    if (mounted) setState(() => _isLoading = false);
  }
}
