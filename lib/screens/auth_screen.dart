import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/error_display.dart';
import '../utils/password_validator.dart';
import '../utils/password_validator.dart';
import 'join_partner_screen.dart';
import '../utils/locations_data.dart';

class AuthScreen extends StatefulWidget {
  static const routeName = '/auth';
  final String? redirectRouteName;

  const AuthScreen({super.key, this.redirectRouteName});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSuccess(BuildContext context) {
    final redirect = widget.redirectRouteName;
    // Defer navigation until next frame to avoid disposing during an active
    // frame which on Web can trigger 'render a disposed EngineFlutterView'.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (redirect != null && redirect.isNotEmpty) {
        Navigator.pushReplacementNamed(context, redirect);
      } else {
        // Pop all routes and go to Home (root)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sign In'),
            Tab(text: 'Sign Up'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SignInForm(onSuccess: () => _onSuccess(context)),
          _SignUpForm(onSuccess: () => _onSuccess(context)),
        ],
      ),
    );
  }
}

class _SignInForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _SignInForm({required this.onSuccess});

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signIn(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ErrorDisplay.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isPasswordVisible,
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Please enter your password'
                    : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              try {
                                await context.read<AuthProvider>().signInWithGoogle();
                                widget.onSuccess();
                              } catch (e) {
                                if (mounted) {
                                  ErrorDisplay.showError(
                                    context,
                                    e.toString().replaceFirst('Exception: ', ''),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                      icon: Image.network(
                        'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                        height: 20,
                        width: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.public, size: 20),
                      ),
                      label: const Text('Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPasswordDialog(context),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              // const Divider(height: 32),
              // SizedBox(
              //   width: double.infinity,
              //   child: OutlinedButton.icon(
              //     onPressed: () {
              //       Navigator.of(context).pushNamed(
              //         JoinPartnerScreen.routeName,
              //       );
              //     },
              //     icon: const Icon(Icons.store),
              //     label: const Text('Join as Partner'),
              //     style: OutlinedButton.styleFrom(
              //       padding: const EdgeInsets.symmetric(vertical: 12),
              //       side: BorderSide(color: Theme.of(context).primaryColor),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.blue),
            SizedBox(width: 8),
            Text('Reset Password'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await context.read<AuthProvider>().resetPassword(
                      email: emailController.text,
                    );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ErrorDisplay.showSuccess(
                    context,
                    'Password reset email sent! Please check your inbox.',
                    duration: const Duration(seconds: 5),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ErrorDisplay.showError(
                    ctx,
                    e.toString().replaceFirst('Exception: ', ''),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}

class _SignUpForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _SignUpForm({required this.onSuccess});

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(); // Added
  final _pincodeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  String? _selectedState;
  final List<String> _availableStates = LocationsData.cities.map((e) => e.state).toSet().toList()..sort();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose(); // Added
    _pincodeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signUp(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
        phoneNumber: _phoneCtrl.text, // Added
        state: _selectedState,
        pincode: _pincodeCtrl.text,
      );
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ErrorDisplay.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter phone number';
                  if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) return 'Enter valid 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(labelText: 'Select State'),
                items: _availableStates.map((state) {
                  return DropdownMenuItem(value: state, child: Text(state));
                }).toList(),
                onChanged: (val) => setState(() => _selectedState = val),
                 validator: (v) => v == null ? 'Please select your state' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pincodeCtrl,
                decoration: const InputDecoration(labelText: 'PIN Code'),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter PIN code';
                  if (v.length != 6) return 'PIN code must be 6 digits';
                  if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'Only numbers allowed';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isPasswordVisible,
                validator: PasswordValidator.validate,
                style: TextStyle(
                  color: (_passCtrl.text.isNotEmpty && 
                          PasswordValidator.validate(_passCtrl.text) == null) 
                      ? Colors.green 
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isConfirmPasswordVisible,
                validator: (v) =>
                    (v != _passCtrl.text) ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              try {
                                await context.read<AuthProvider>().signInWithGoogle();
                                widget.onSuccess();
                              } catch (e) {
                                if (mounted) {
                                  ErrorDisplay.showError(
                                    context,
                                    e.toString().replaceFirst('Exception: ', ''),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                      icon: Image.network(
                        'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                        height: 20,
                        width: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.public, size: 20),
                      ),
                      label: const Text('Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
