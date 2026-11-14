import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ─── Mode ────────────────────────────────────────────
  bool _isSignUp = false;

  // ─── Form ────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // shared
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // sign-up only
  final _pharmacyNameCtrl = TextEditingController();
  final _handlerNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pharmacyNameCtrl.dispose();
    _handlerNameCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _animCtrl.reset();
    setState(() => _isSignUp = !_isSignUp);
    _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Logo ──
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded,
                          color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 20),
                    Text('PharmaDash',
                        style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      _isSignUp
                          ? 'Register your pharmacy to get started'
                          : 'Sign in to manage your pharmacy',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // ── Sign-Up Extra Fields ──────────────────────────────
                    if (_isSignUp) ...[
                      _label('Pharmacy Name', colors),
                      _field(
                        controller: _pharmacyNameCtrl,
                        hint: 'e.g. Al-Shifa Pharmacy',
                        icon: Icons.local_pharmacy_outlined,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _label('Handler Name', colors),
                      _field(
                        controller: _handlerNameCtrl,
                        hint: 'e.g. Ahmed Khan',
                        icon: Icons.person_outline_rounded,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('City', colors),
                                _field(
                                  controller: _cityCtrl,
                                  hint: 'e.g. Karachi',
                                  icon: Icons.location_city_outlined,
                                  validator: (v) =>
                                      v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Area', colors),
                                _field(
                                  controller: _areaCtrl,
                                  hint: 'e.g. Gulshan',
                                  icon: Icons.map_outlined,
                                  validator: (v) =>
                                      v!.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Shared Fields ─────────────────────────────────────
                    _label('Email', colors),
                    _field(
                      controller: _emailCtrl,
                      hint: 'pharmacy@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _label('Password', colors),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: GoogleFonts.inter(color: colors.textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outlined),
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v!.isEmpty) return 'Required';
                        if (_isSignUp && v.length < 6) {
                          return 'Min 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Submit Button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _isSignUp ? 'Register Pharmacy' : 'Sign In',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Toggle ────────────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _toggleMode,
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                                fontSize: 14, color: colors.textSecondary),
                            children: [
                              TextSpan(
                                  text: _isSignUp
                                      ? 'Already registered? '
                                      : "Don't have an account? "),
                              TextSpan(
                                text: _isSignUp ? 'Sign In' : 'Register',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _label(String text, AppColors colors) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
      ),
      validator: validator,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await ref.read(authServiceProvider).signUp(
              email: _emailCtrl.text,
              password: _passCtrl.text,
              pharmacyName: _pharmacyNameCtrl.text,
              handlerName: _handlerNameCtrl.text,
              city: _cityCtrl.text,
              area: _areaCtrl.text,
            );
      } else {
        await ref.read(authServiceProvider).signIn(
              _emailCtrl.text,
              _passCtrl.text,
            );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: AppColors.error,
        ));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'This email is already registered. Please sign in.';
    }
    if (raw.contains('user-not-found') || raw.contains('wrong-password') || raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('weak-password')) return 'Password is too weak.';
    if (raw.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
