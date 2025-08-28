// lib/screens/login/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:business_management_app/services/auth_service.dart';
import 'package:business_management_app/utils/app_notifications.dart';
import 'package:business_management_app/theme/app_theme.dart';
import 'package:business_management_app/widgets/app_background.dart'; // 1. Import AppBackground

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _loading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _animController,
    curve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _userFocus.unfocus();
    _passFocus.unfocus();

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
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with that username.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password provided.';
          break;
        default:
          errorMessage = 'Invalid username or password.';
      }
      if (mounted) {
        showAppNotification(
          context: context,
          message: errorMessage,
          type: NotificationType.error,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppNotification(
          context: context,
          message: 'An unexpected error occurred.',
          type: NotificationType.error,
        );
      }
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
      // 2. Set background to transparent
      backgroundColor: Colors.transparent,
      // 3. Wrap the body with the AppBackground widget
      body: AppBackground(
        child: Center(
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
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.terrain,
                              size: 64,
                              color: AppColors.primary.withOpacity(0.8),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              ' COLD STORAGE',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _usernameCtrl,
                              focusNode: _userFocus,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).requestFocus(_passFocus);
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your username';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_loading) {
                                  _login();
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) => setState(() {
                                    _rememberMe = value ?? false;
                                  }),
                                ),
                                const Text('Remember me'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('LOG IN'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
