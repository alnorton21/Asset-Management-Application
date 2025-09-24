import 'package:flutter/material.dart';
import 'home_shell.dart';
import '../services/auth_service.dart';

/// ---------- Shared layout for both login and sign up -----------
class _AuthShell extends StatelessWidget {
  const _AuthShell({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isDark,
    required this.onToggleTheme,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: isDark ? 'Light theme' : 'Dark theme',
            onPressed: onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 950;
          return Row(
            children: [
              if (wide)
                Expanded(
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF0E1B2A), const Color(0xFF132C4A)]
                            : [const Color(0xFFBFD7FF), const Color(0xFFEEF4FF)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.onPrimary.withOpacity(0.12),
                              ),
                              child: Icon(Icons.map_outlined, size: 44, color: cs.onSurface),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 48 : 20,
                        vertical: wide ? 48 : 16,
                      ),
                      child: Material(
                        elevation: 12,
                        borderRadius: BorderRadius.circular(28),
                        color: cs.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ---------- Pretty Input ----------
InputDecoration _decor(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

/// ---------- LOGIN PAGE ----------
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(); // can be username or email
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    final id = _username.text.trim();
    // If the user types an email, send it as email; otherwise as username.
    final r = id.contains('@')
        ? await AuthService.login(email: id, password: _password.text)
        : await AuthService.login(username: id, password: _password.text);

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.msg)));

    if (r.ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeShell(
            isDark: widget.isDark,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      title: 'Welcome back',
      subtitle: 'Sign in to manage assets, images, and maps.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Login',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _username,
              decoration: _decor('Username or Email', Icons.person),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Username or Email is required';
                if (v.trim().length > 50) return 'Max 50 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              decoration: _decor('Password', Icons.lock).copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length > 50) return 'Max 50 characters';
                return null;
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () {}, child: const Text('Forgot password?')),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log in'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) => SignUpPage(
                        isDark: widget.isDark,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                    ),
                  ),
                  child: const Text('Create one'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}





/// ---------- SIGN-UP PAGE ----------
class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

   // SIGN UP API CALL

  Future<void> _submit() async {
  if (!_form.currentState!.validate()) return;
  setState(() => _busy = true);

  final r = await AuthService.signup(
    username: _username.text.trim(),
    email: _email.text.trim(),
    phone: _phone.text.trim(),
    password: _password.text,
  );

  if (!mounted) return;
  setState(() => _busy = false);

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.msg)));

  if (r.ok) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          isDark: widget.isDark,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }
}   

  String? _vEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email';
    if (v.trim().length > 50) return 'Max 50 characters';
    return null;
  }

  String? _vPhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length < 7 || d.length > 15) return '7–15 digits';
    if (v.trim().length > 50) return 'Max 50 characters';
    return null;
  }

  String? _vUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Username is required';
    if (v.trim().length < 3) return 'Min 3 characters';
    if (v.trim().length > 50) return 'Max 50 characters';
    return null;
  }

  String? _vPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Min 6 characters';
    if (v.length > 50) return 'Max 50 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _AuthShell(
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      title: 'Create your account',
      subtitle: 'Start capturing assets, photos & locations.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sign Up', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _username,
              decoration: _decor('Username', Icons.person),
              validator: _vUsername,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              decoration: _decor('Email', Icons.email),
              keyboardType: TextInputType.emailAddress,
              validator: _vEmail,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              decoration: _decor('Phone number', Icons.phone),
              keyboardType: TextInputType.phone,
              validator: _vPhone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              decoration: _decor('Password', Icons.lock).copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              validator: _vPassword,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Account'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Already have an account? Log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
