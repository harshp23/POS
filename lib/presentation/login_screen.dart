import 'package:flutter/material.dart';

import 'dashboard/dashboard_widgets.dart' show friendlyErrorText;

enum UserRole {
  superAdmin,
  posOperator,
}

enum AuthMode {
  signIn,
  resetPassword,
  signUp,
}

class LoginScreen extends StatefulWidget {
  final Function({required UserRole role, required String email})
      onLoginSuccess;

  /// Real sign-in through the Proviyaa backend (Supabase Auth behind it).
  /// Returns the panel the account's role opens; throws with a message the
  /// screen shows on failure. When null (no backend configured) the screen
  /// keeps the offline demo sign-in.
  final Future<UserRole> Function(String email, String password)?
      onBackendSignIn;

  /// Shown above the form (e.g. why a saved login could not be used).
  final String? notice;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.onBackendSignIn,
    this.notice,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthMode _authMode = AuthMode.signIn;

  // Sign In fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Reset Password field
  final _resetEmailController = TextEditingController();

  // Sign Up fields
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;
  String? _errorMessage;
  int _failedAttempts = 0;

  bool _signingIn = false;

  Future<void> _handleBackendSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });
    try {
      final role = await widget.onBackendSignIn!(email, password);
      if (!mounted) return;
      widget.onLoginSuccess(role: role, email: email);
    } catch (e) {
      if (!mounted) return;
      // The server counts failed attempts and locks the login; its message
      // says what went wrong (not every failure is a wrong password).
      setState(() => _errorMessage = friendlyErrorText(e,
          fallback: 'Could not sign in. Please try again.'));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _handleSignIn() {
    if (widget.onBackendSignIn != null) {
      _handleBackendSignIn();
      return;
    }
    var email = _emailController.text.trim();
    var password = _passwordController.text.trim();

    // Default demo fallback if submitted empty
    if (email.isEmpty) email = 'admin@onelatur.com';
    if (password.isEmpty) password = 'admin123';

    // Role mapping based on email/role:
    // admin / owner / super -> SuperAdmin (Franchise Vendor Panel)
    // shop / cashier / pos -> PosOperator (POS Billing Terminal)
    if (email.contains('admin') ||
        email.contains('owner') ||
        email.contains('proviyaa')) {
      if (password == 'admin123' ||
          password == 'password123' ||
          password.isNotEmpty) {
        widget.onLoginSuccess(role: UserRole.superAdmin, email: email);
      } else {
        _handleInvalidPassword();
      }
    } else {
      if (password == 'pos123' ||
          password == 'admin123' ||
          password.isNotEmpty) {
        widget.onLoginSuccess(role: UserRole.posOperator, email: email);
      } else {
        _handleInvalidPassword();
      }
    }
  }

  void _handleInvalidPassword() {
    setState(() {
      _failedAttempts++;
      _errorMessage =
          'Invalid email or password. Please check your credentials and try again.';
    });
  }

  void _handleSendResetLink() {
    if (widget.onBackendSignIn != null) {
      // There is no self-service reset: restaurant logins are reset by the
      // restaurant's admin (Staff → Login security) or by Proviyaa.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Ask your restaurant admin to reset your password (Staff & Users → Login security). They can give you a temporary one.')));
      return;
    }
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your registered email')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password reset link sent to $email'),
        backgroundColor: Colors.green[800],
      ),
    );
    setState(() {
      _authMode = AuthMode.signIn;
    });
  }

  void _handleSignUp() {
    if (widget.onBackendSignIn != null) {
      // Restaurant accounts are created by Proviyaa onboarding (the OS
      // creates the organization, branches and first admin); the POS
      // doesn't create tenants on its own.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'New restaurant accounts are set up by Proviyaa onboarding. Contact your Proviyaa account manager, then sign in here.')));
      return;
    }
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms of Service')),
      );
      return;
    }
    final email = _signUpEmailController.text.trim();
    final storeName = _storeNameController.text.trim();
    if (email.isEmpty || storeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Store account "$storeName" created successfully!'),
        backgroundColor: Colors.green[800],
      ),
    );
    widget.onLoginSuccess(
        role: UserRole.superAdmin,
        email: email.isNotEmpty ? email : 'owner@onelatur.com');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF5F6F8);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(36.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
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
              children: [
                // Top Brand Avatar Badge (Lime Green Circle with "OL")
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF76EC00), // Lime Green
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'OL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Switch View Content
                switch (_authMode) {
                  AuthMode.signIn => _buildSignInView(context, isDark),
                  AuthMode.resetPassword =>
                    _buildResetPasswordView(context, isDark),
                  AuthMode.signUp => _buildSignUpView(context, isDark),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Sign In View (Matching Screenshots 1 & 4)
  Widget _buildSignInView(BuildContext context, bool isDark) {
    final isError = _errorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Restaurant POS Sign In',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2029),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'One login for the whole store — access is controlled by your role.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        if (widget.notice != null && !isError) ...[
          Container(
            key: const Key('login-notice'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Text(widget.notice!,
                style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ),
          const SizedBox(height: 16),
        ],

        // Error Warning Banner (Matching Screenshot 1)
        if (isError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Email Field
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email Address',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'admin@onelatur.com',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isError ? Colors.red : const Color(0xFF76EC00),
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Password Field Label + Forgot Password link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _authMode = AuthMode.resetPassword;
                });
              },
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32), // Darker green for link
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          // Enter signs in, as on any login form.
          textInputAction: TextInputAction.go,
          onSubmitted: (_) {
            if (!_signingIn) _handleSignIn();
          },
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 13,
              letterSpacing: 2,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey[600],
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isError ? Colors.red : const Color(0xFF76EC00),
                width: 2,
              ),
            ),
          ),
        ),

        // Failed Attempts Inline Warning
        if (_failedAttempts > 0) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Incorrect password. ${(3 - _failedAttempts).clamp(0, 3)} attempts remaining.',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Main Sign In Button (Lime Green Button matching screenshots)
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _signingIn ? null : _handleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF76EC00), // Lime Green
              foregroundColor: Colors.white,
              elevation: 0,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(_signingIn ? 'Signing in…' : 'Sign In'),
          ),
        ),
        const SizedBox(height: 20),

        // Don't have an account? Sign Up
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Don\'t have an account? ',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _authMode = AuthMode.signUp;
                });
              },
              child: const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Divider(height: 1),
        const SizedBox(height: 16),

        Text(
          'Unauthorized access is prohibited and monitored.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  // 2. Reset Password View (Matching Screenshot 2)
  Widget _buildResetPasswordView(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2029),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your registered email address and we\'ll send you a reset link.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Email Address',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _resetEmailController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'shop.admin@onelatur.com',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _handleSendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF76EC00),
              foregroundColor: Colors.white,
              elevation: 0,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Send Reset Link'),
          ),
        ),
        const SizedBox(height: 18),

        InkWell(
          onTap: () {
            setState(() {
              _authMode = AuthMode.signIn;
            });
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 14, color: Color(0xFF2E7D32)),
              SizedBox(width: 6),
              Text(
                'Back to Sign In',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Spam Warning Info Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check your spam folder if you don\'t receive the email within 5 minutes.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. Create Store Account View (Matching Screenshot 3)
  Widget _buildSignUpView(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Create Store Account',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2029),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up your OneLatur Store POS account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),

        _buildLabel('Store Name'),
        const SizedBox(height: 4),
        _buildTextField(_storeNameController, 'e.g. Latur Supermarket'),
        const SizedBox(height: 14),

        _buildLabel('Owner Name'),
        const SizedBox(height: 4),
        _buildTextField(_ownerNameController, 'e.g. Amit Patil'),
        const SizedBox(height: 14),

        _buildLabel('Email Address'),
        const SizedBox(height: 4),
        _buildTextField(_signUpEmailController, 'owner@onelatur.com'),
        const SizedBox(height: 14),

        _buildLabel('Phone Number'),
        const SizedBox(height: 4),
        TextField(
          controller: _phoneController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            prefixText: '+91 |  ',
            prefixStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            hintText: '98765 43210',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
        const SizedBox(height: 14),

        _buildLabel('Password'),
        const SizedBox(height: 4),
        TextField(
          controller: _signUpPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 13,
              letterSpacing: 2,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Password Strength Indicator Bar
        Row(
          children: [
            Text(
              'Password strength',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            const Spacer(),
            const Text(
              'Strong',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildLabel('Confirm Password'),
        const SizedBox(height: 4),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 13,
              letterSpacing: 2,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Terms Checkbox
        Row(
          children: [
            Checkbox(
              value: _agreeTerms,
              activeColor: const Color(0xFF76EC00),
              onChanged: (val) => setState(() => _agreeTerms = val ?? false),
            ),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _handleSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF76EC00),
              foregroundColor: Colors.white,
              elevation: 0,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create Account'),
          ),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _authMode = AuthMode.signIn;
                });
              },
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2029),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}
