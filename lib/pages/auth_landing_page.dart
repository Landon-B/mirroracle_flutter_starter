import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';

class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key});

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecache) return;
    _didPrecache = true;
    precacheImage(
      const AssetImage('assets/images/mirrorcle_logo.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/mirrorcle_text.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF2F0F6),
              Color(0xFFDAD4E1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const _LogoBlock(),
              const SizedBox(height: 4),
              Text(
                'Positive self-talk,\ngrounded in self-reflection',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  height: 1.35,
                  color: Colors.black.withOpacity(0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    _PrimaryButton(
                      label: 'Create Account',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateAccountFlowPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _OutlineButton(
                      label: 'Sign-in',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateAccountFlowPage extends StatefulWidget {
  const CreateAccountFlowPage({super.key});

  @override
  State<CreateAccountFlowPage> createState() => _CreateAccountFlowPageState();
}

class _CreateAccountFlowPageState extends State<CreateAccountFlowPage> {
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _stepIndex = 0;
  bool _loading = false;
  bool _codeSent = false;
  String? _error;
  bool? _notificationChoice;
  String? _notificationError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitFirstName() async {
    final name = _firstNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your first name.');
      return;
    }
    setState(() {
      _error = null;
      _stepIndex = 1;
    });
  }

  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
      });
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyEmailCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code we sent to your email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        token: code,
        email: email,
      );
      final session = response.session;
      if (session == null) {
        setState(() => _error = 'We could not verify that code. Try again.');
        return;
      }
      if (!mounted) return;
      setState(() => _stepIndex = 2);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: password,
          data: {'first_name': _firstNameController.text.trim()},
        ),
      );
      if (!mounted) return;
      setState(() => _stepIndex = 3);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleNotifications() async {
    if (_notificationChoice == null) {
      setState(() => _notificationError = 'Select an option to continue.');
      return;
    }
    if (_notificationChoice == true) {
      await Permission.notification.request();
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final background = const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF2F0F6),
          Color(0xFFDAD4E1),
        ],
      ),
    );

    return Scaffold(
      body: Container(
        decoration: background,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _stepIndex == 0
                ? _NameStep(
                    controller: _firstNameController,
                    error: _error,
                    loading: _loading,
                    onNext: _submitFirstName,
                  )
                : _stepIndex == 1
                    ? _EmailStep(
                        emailController: _emailController,
                        codeController: _codeController,
                        codeSent: _codeSent,
                        error: _error,
                        loading: _loading,
                        onSend: _sendEmailCode,
                        onVerify: _verifyEmailCode,
                      )
                    : _stepIndex == 2
                        ? _PasswordStep(
                            passwordController: _passwordController,
                            confirmController: _confirmPasswordController,
                            error: _error,
                            loading: _loading,
                            onNext: _submitPassword,
                          )
                        : _NotificationStep(
                            selection: _notificationChoice,
                            error: _notificationError,
                            onSelect: (value) {
                              setState(() {
                                _notificationChoice = value;
                                _notificationError = null;
                              });
                            },
                            onContinue: _handleNotifications,
                          ),
          ),
        ),
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/mirrorcle_logo.png',
          width: 350,
          height: 350,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.panorama_fish_eye_outlined,
              size: 62,
              color: Colors.black87,
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Mirrorcle',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 40,
            letterSpacing: 0.6,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.error,
    required this.loading,
    required this.onNext,
  });

  final TextEditingController controller;
  final String? error;
  final bool loading;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                "What's your first name?",
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This helps us personalize your experience.',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'first name',
                  hintStyle: GoogleFonts.manrope(color: Colors.black38),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black87, width: 1.6),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _ArrowButton(
            onTap: loading ? null : onNext,
          ),
        ),
      ],
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.emailController,
    required this.codeController,
    required this.codeSent,
    required this.error,
    required this.loading,
    required this.onSend,
    required this.onVerify,
  });

  final TextEditingController emailController;
  final TextEditingController codeController;
  final bool codeSent;
  final String? error;
  final bool loading;
  final VoidCallback onSend;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                "What's your email?",
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Email verification helps us keep your account secure.',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'email@example.com',
                  hintStyle: GoogleFonts.manrope(color: Colors.black38),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black87, width: 1.6),
                  ),
                ),
              ),
              if (codeSent) ...[
                const SizedBox(height: 24),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Verification code',
                    hintStyle: GoogleFonts.manrope(color: Colors.black38),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black26),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.black87, width: 1.6),
                    ),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _ArrowButton(
            onTap: loading
                ? null
                : codeSent
                    ? onVerify
                    : onSend,
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class _NotificationStep extends StatelessWidget {
  const _NotificationStep({
    required this.selection,
    required this.error,
    required this.onSelect,
    required this.onContinue,
  });

  final bool? selection;
  final String? error;
  final ValueChanged<bool> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Gentle reminders,\nwhen you want them.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              _ChoiceButton(
                label: 'Enable Notifications',
                isSelected: selection == true,
                onTap: () => onSelect(true),
              ),
              const SizedBox(height: 12),
              _ChoiceButton(
                label: 'Disable Notifications',
                isSelected: selection == false,
                onTap: () => onSelect(false),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _ArrowButton(
            onTap: onContinue,
          ),
        ),
      ],
    );
  }
}

class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.passwordController,
    required this.confirmController,
    required this.error,
    required this.loading,
    required this.onNext,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String? error;
  final bool loading;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Create your password',
                style: GoogleFonts.manrope(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a password you will remember.',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: GoogleFonts.manrope(color: Colors.black38),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black87, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: confirmController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Confirm password',
                  hintStyle: GoogleFonts.manrope(color: Colors.black38),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black87, width: 1.6),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _ArrowButton(
            onTap: loading ? null : onNext,
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEDEAF1),
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.black26),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Colors.black26, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: BorderSide(
            color: isSelected ? Colors.black87 : Colors.black26,
            width: isSelected ? 2.2 : 1.6,
          ),
          backgroundColor: isSelected ? Colors.white : const Color(0xFFEDEAF1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.onTap, this.loading = false});

  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 28),
          ),
        ),
      ),
    );
  }
}
