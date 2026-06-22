import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/help_content.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_notification.dart';
import '../../widgets/tap_tooltip.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final user = authProvider.user;
      if (user != null) {
        AppNotification.success(context, 'Welcome back, ${user.fullName ?? user.email}!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      AppNotification.error(
        context,
        authProvider.error ?? 'Login failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo - App icon
                Center(
                  child: TapTooltip(
                    title: 'Winter Intelligence Engine',
                    message: HelpContent.loginLogo,
                    child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [AppColors.blueShadow()],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/app_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                ),
                SizedBox(height: 48),
                
                // Title - Outside card for better spacing
                TapTooltip(
                  title: 'Welcome Back',
                  message: HelpContent.screenLogin,
                  child: Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                ),
                SizedBox(height: 12),
                Text(
                  'Sign in to access your portal',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary, // gray-400
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                
                // Form - No card wrapper for cleaner mobile look
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email Label
                      HelpLabel(
                        label: 'Email Address',
                        help: HelpContent.loginEmail,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        iconColor: Color(0xFF93C5FD),
                      ),
                      SizedBox(height: 10),
                      TapTooltip(
                        title: 'Email Address',
                        message: HelpContent.loginEmail,
                        triggerOnLongPressOnly: true,
                        child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'you@example.com',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 16),
                          filled: true,
                          fillColor: AppColors.slate900.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.borderLight, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.borderLight, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.blue500, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.error, width: 1),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.error, width: 2),
                          ),
                          errorStyle: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      ),
                      SizedBox(height: 24),
                      
                      // Password Label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: HelpLabel(
                              label: 'Password',
                              help: HelpContent.loginPassword,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              iconColor: Color(0xFF93C5FD),
                            ),
                          ),
                          TapTooltip(
                            title: 'Forgot password?',
                            message: HelpContent.loginForgotPassword,
                            triggerOnLongPressOnly: true,
                            child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Color(0xFF60A5FA),
                            ),
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      TapTooltip(
                        title: 'Password',
                        message: HelpContent.loginPassword,
                        triggerOnLongPressOnly: true,
                        child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 16),
                          filled: true,
                          fillColor: AppColors.slate900.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.borderLight, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.borderLight, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.blue500, width: 2),
                          ),
                          errorStyle: TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      ),
                      SizedBox(height: 32),
                      
                      // Submit Button - Bigger and more prominent
                      TapTooltip(
                        title: 'Sign In',
                        message: HelpContent.loginSignIn,
                        triggerOnLongPressOnly: true,
                        child: Consumer<AuthProvider>(
                        builder: (context, authProvider, _) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF2563EB), // blue-600
                                  AppColors.blue500, // blue-500
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.blue500.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: authProvider.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: authProvider.isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
                
                // Register Link - Outside card
                Center(
                  child: TapTooltip(
                    title: 'Sign up',
                    message: HelpContent.loginSignUp,
                    triggerOnLongPressOnly: true,
                    child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFF60A5FA), // blue-400
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
              Positioned(
                top: 8,
                right: 8,
                child: ScreenHelpAction(
                  title: 'Sign In',
                  message: HelpContent.screenLogin,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
