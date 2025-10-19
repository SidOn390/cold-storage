// lib/screens/login/login_screen.dart

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cold_storage/services/auth_service.dart';
import 'package:cold_storage/utils/app_notifications.dart';
import 'package:cold_storage/theme/app_theme.dart';
import 'package:cold_storage/widgets/app_background.dart'; // 1. Import AppBackground

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
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _loading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _biometricOptIn = false;
  bool _biometricInProgress = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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

    final wantsBiometric = prefs.getBool('biometric_login') ?? false;
    bool biometricsReady = false;
    if (_isAndroid) {
      try {
        final supported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        final availableBiometrics = canCheck
            ? await _localAuth.getAvailableBiometrics()
            : <BiometricType>[];
        biometricsReady =
            supported && canCheck && availableBiometrics.isNotEmpty;
      } on PlatformException {
        biometricsReady = false;
      } on MissingPluginException {
        biometricsReady = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      _biometricAvailable = biometricsReady;
      _biometricOptIn = wantsBiometric && biometricsReady;
    });
  }

  void _showBiometricError(String message) {
    if (!mounted) return;
    showAppNotification(
      context: context,
      message: message,
      type: NotificationType.error,
    );
  }

  Future<bool> _ensureBiometricReady() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) {
        _showBiometricError('Biometric hardware not available on this device.');
        return false;
      }
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        _showBiometricError('No biometric sensor detected.');
        return false;
      }
      final biometrics = await _localAuth.getAvailableBiometrics();
      if (biometrics.isEmpty) {
        _showBiometricError(
          'No biometrics are enrolled. Add a fingerprint or face ID in system settings.',
        );
        return false;
      }
      return true;
    } on PlatformException catch (e) {
      _showBiometricError(
        e.message ?? 'Biometric authentication is unavailable right now.',
      );
      return false;
    } on MissingPluginException {
      _showBiometricError(
        'Biometric authentication plugin is not available in this build.',
      );
      return false;
    }
  }

  Future<void> _onBiometricToggle(bool enable) async {
    if (enable && !await _ensureBiometricReady()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_login', enable);
    if (!enable) {
      await _secureStorage.delete(key: 'biometric_username');
      await _secureStorage.delete(key: 'biometric_password');
    } else if (mounted) {
      showAppNotification(
        context: context,
        message:
            'Biometric login enabled. Sign in once with your password to finish setup.',
        type: NotificationType.info,
      );
    }

    if (!mounted) return;
    setState(() {
      _biometricOptIn = enable;
      if (enable) {
        _biometricAvailable = true;
      }
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_biometricOptIn || _loading || _biometricInProgress) {
      return;
    }
    setState(() {
      _biometricInProgress = true;
    });

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to log in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!didAuthenticate) {
        return;
      }

      final username = await _secureStorage.read(key: 'biometric_username');
      final password = await _secureStorage.read(key: 'biometric_password');

      if (username == null || password == null) {
        _showBiometricError(
          'Biometric login is not configured. Sign in with your password once to set it up.',
        );
        return;
      }

      _usernameCtrl.text = username;
      _passCtrl.text = password;

      await _login();
    } on PlatformException catch (e) {
      _showBiometricError(e.message ?? 'Unable to use biometrics right now.');
    } on MissingPluginException {
      _showBiometricError('Biometric authentication plugin is not registered.');
    } finally {
      if (mounted) {
        setState(() {
          _biometricInProgress = false;
        });
      }
    }
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

      if (_isAndroid) {
        if (_biometricOptIn) {
          await _secureStorage.write(
            key: 'biometric_username',
            value: _usernameCtrl.text.trim(),
          );
          await _secureStorage.write(
            key: 'biometric_password',
            value: _passCtrl.text,
          );
          await prefs.setBool('biometric_login', true);
          if (mounted) {
            setState(() {
              _biometricAvailable = true;
            });
          }
        } else {
          await _secureStorage.delete(key: 'biometric_username');
          await _secureStorage.delete(key: 'biometric_password');
          await prefs.setBool('biometric_login', false);
        }
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
                            if (_isAndroid)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _biometricOptIn,
                                  onChanged:
                                      (_loading ||
                                          (!_biometricAvailable &&
                                              !_biometricOptIn))
                                      ? null
                                      : _onBiometricToggle,
                                  title: const Text('Enable biometric login'),
                                  subtitle:
                                      !_biometricAvailable && !_biometricOptIn
                                      ? const Text(
                                          'Biometrics unavailable on this device.',
                                        )
                                      : null,
                                ),
                              ),
                            if (_isAndroid) const SizedBox(height: 8),
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
                            if (_isAndroid &&
                                _biometricOptIn &&
                                _biometricAvailable)
                              const SizedBox(height: 12),
                            if (_isAndroid &&
                                _biometricOptIn &&
                                _biometricAvailable)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: (_loading || _biometricInProgress)
                                      ? null
                                      : _authenticateWithBiometrics,
                                  icon: _biometricInProgress
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.fingerprint),
                                  label: Text(
                                    _biometricInProgress
                                        ? 'Waiting for biometrics...'
                                        : 'LOGIN WITH BIOMETRICS',
                                  ),
                                ),
                              ),
                            // Setup button for first-time super admin creation
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/setup/initial');
                              },
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('First Time Setup'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
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
