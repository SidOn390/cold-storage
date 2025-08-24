// lib/screens/login/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
// --- CHANGE: Use package imports ---
import 'package:business_management_app/services/auth_service.dart';
import 'package:business_management_app/utils/auth_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  bool _loading = false;
  String? _error;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _usernameError = false;
  bool _passwordError = false;

  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _animController,
    curve: Curves.easeIn,
  );

  // Brand colors
  final Color _primaryColor = Colors.teal;
  final Color _accentColor = Colors.tealAccent;

  @override
  void initState() {
    super.initState();

    _animController.forward();
    _loadRememberMe();

    _userFocus.addListener(() {
      if (!_userFocus.hasFocus) {
        setState(() {
          _usernameError = _usernameCtrl.text.trim().isEmpty;
        });
      }
    });
    _passFocus.addListener(() {
      if (!_passFocus.hasFocus) {
        setState(() {
          _passwordError = _passCtrl.text.isEmpty;
        });
      }
    });
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    if (remember) {
      _usernameCtrl.text = prefs.getString('username') ?? '';
      _passCtrl.text = prefs.getString('password') ?? '';
    }
    setState(() {
      _rememberMe = remember;
    });
  }

  Future<void> _login() async {
    // Unfocus fields to hide keyboard
    _userFocus.unfocus();
    _passFocus.unfocus();

    // Inline validation
    setState(() {
      _usernameError = _usernameCtrl.text.trim().isEmpty;
      _passwordError = _passCtrl.text.isEmpty;
      _error = null;
    });
    if (_usernameError || _passwordError) return;

    setState(() {
      _loading = true;
    });

    try {
      await AuthService().signInWithUsername(
        username: _usernameCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('username', _usernameCtrl.text.trim());
        await prefs.setString('password', _passCtrl.text);
      } else {
        await prefs.setBool('remember_me', false);
        await prefs.remove('username');
        await prefs.remove('password');
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _error = 'No user found';
          break;
        case 'wrong-password':
          _error = 'Incorrect password';
          break;
        default:
          _error = 'Invalid username or password';
      }
    } catch (_) {
      _error = 'Unexpected error occurred';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Log In'),
        backgroundColor: _primaryColor,
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 400
                ? constraints.maxWidth * 0.9
                : 400.0;
            return FadeTransition(
              opacity: _fadeAnim,
              child: SizedBox(
                width: width,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _usernameCtrl,
                          focusNode: _userFocus,
                          autofocus:
                              true, // --- ADDED: Autofocus on username ---
                          textInputAction: TextInputAction
                              .next, // --- ADDED: Show "next" on keyboard ---
                          onSubmitted: (_) {
                            // --- ADDED: Move to password field on "next" ---
                            FocusScope.of(context).requestFocus(_passFocus);
                          },
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(
                              Icons.person,
                              semanticLabel: 'Username',
                            ),
                            errorText: _usernameError ? 'Required' : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passCtrl,
                          focusNode: _passFocus,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction
                              .done, // --- ADDED: Show "done" on keyboard ---
                          onSubmitted: (_) {
                            // --- ADDED: Attempt login on "done" ---
                            if (!_loading) {
                              _login();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(
                              Icons.lock,
                              semanticLabel: 'Password',
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                semanticLabel: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            errorText: _passwordError ? 'Required' : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: _primaryColor,
                              onChanged: (value) => setState(() {
                                _rememberMe = value ?? false;
                              }),
                            ),
                            const Text('Remember me'),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors
                                          .white, // --- IMPROVED: Set color to white
                                    ),
                                  )
                                : const Text(
                                    // --- IMPROVED: Added const
                                    'Log In',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
