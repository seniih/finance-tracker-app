import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLogin = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('E-posta ve şifre alanları boş bırakılamaz.');
      return;
    }
    
    if (!_isLogin && password != _confirmPasswordCtrl.text) {
      _showError('Şifreler eşleşmiyor, lütfen kontrol edin.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: kIsWeb ? null : 'io.supabase.trendarsa://login-callback/',
        );
        if (mounted) {
          _showSuccess('Kayıt başarılı! Lütfen mailinizi onaylayın.');
          setState(() => _isLogin = true);
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo / Başlık
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.primary, size: 28),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isLogin ? 'Hoş Geldiniz' : 'Hesap Oluştur',
                      key: ValueKey<bool>(_isLogin),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isLogin 
                          ? 'TrendArsa Muhasebe\'ye giriş yapın' 
                          : 'TrendArsa ailesine katılmak için kayıt olun',
                      key: ValueKey<bool>(_isLogin),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // E-posta
                Text('E-posta',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'ornek@sirket.com',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.mail_outline_rounded,
                        color: AppColors.textSecondary, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 2)),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Şifre
                Text('Şifre',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.textSecondary, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 2)),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
                
                // Şifre Tekrarı (Sadece Kayıt Ol)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _isLogin
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Text('Şifre Tekrarı',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _confirmPasswordCtrl,
                              obscureText: _obscureConfirmPassword,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: const TextStyle(color: AppColors.textSecondary),
                                prefixIcon: const Icon(Icons.lock_outline_rounded,
                                    color: AppColors.textSecondary, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: AppColors.primary, width: 2)),
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 28),

                // Giriş Butonu
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Toggle Butonu
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin 
                          ? 'Hesabınız yok mu? Kayıt olun'
                          : 'Zaten hesabınız var mı? Giriş yapın',
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
