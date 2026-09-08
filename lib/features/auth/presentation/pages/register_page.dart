import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/auth_providers.dart';
import '../../domain/entities/auth_entity.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          passwordConfirmation: _confirmController.text,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next is Authenticated) {
        context.go('/');
      } else if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.red),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });

    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context,
                  mobile: 20, tablet: 24, desktop: 32)),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth:
                      Responsive.isDesktop(context) ? 480 : double.infinity),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 28, tablet: 40, desktop: 48)),
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.cookie,
                            size: 38, color: theme.colorScheme.onPrimary),
                      ),
                    ),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 14, tablet: 20, desktop: 24)),
                    const Text('Buat Akun',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 6, tablet: 8, desktop: 10)),
                    const Text('Daftar untuk mulai berbelanja',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 24, tablet: 32, desktop: 40)),
                    _buildField(
                        _nameController,
                        'Nama Lengkap',
                        'Masukkan nama',
                        Icons.person_outline,
                        (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 10, tablet: 14, desktop: 16)),
                    _buildField(_emailController, 'Email', 'Masukkan email',
                        Icons.email_outlined, (v) {
                      if (v == null || v.isEmpty) return 'Wajib diisi';
                      if (!v.contains('@')) return 'Email tidak valid';
                      return null;
                    }, keyboardType: TextInputType.emailAddress),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 10, tablet: 14, desktop: 16)),
                    _buildField(
                        _phoneController,
                        'No. Telepon',
                        'Masukkan no. telepon',
                        Icons.phone_outlined,
                        (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                        keyboardType: TextInputType.phone),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 10, tablet: 14, desktop: 16)),
                    _buildField(_passwordController, 'Kata Sandi',
                        'Minimal 6 karakter', Icons.lock_outline, (v) {
                      if (v == null || v.isEmpty) return 'Wajib diisi';
                      if (v.length < 6) return 'Minimal 6 karakter';
                      return null;
                    }, obscure: _obscure),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 10, tablet: 14, desktop: 16)),
                    _buildField(_confirmController, 'Konfirmasi Sandi',
                        'Ulangi kata sandi', Icons.lock_outline, (v) {
                      if (v != _passwordController.text)
                        return 'Sandi tidak cocok';
                      return null;
                    }, obscure: _obscure),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 16, tablet: 24, desktop: 32)),
                    SizedBox(
                      height: Responsive.spacing(context,
                          mobile: 48, tablet: 52, desktop: 56),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary))
                            : const Text('Daftar',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 16, tablet: 24, desktop: 32)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Sudah punya akun? ',
                            style: TextStyle(fontSize: 14)),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Text('Masuk',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                    SizedBox(
                        height: Responsive.spacing(context,
                            mobile: 28, tablet: 40, desktop: 48)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String label, String hint,
      IconData icon, String? Function(String?)? validator,
      {TextInputType? keyboardType, bool obscure = false}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
