import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signUp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your email to confirm your account.')),
      );
    } on AuthException catch (e) {
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = 'Unexpected error: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      setState(() { _error = e.message; });
    } catch (e) {
      setState(() { _error = 'Unexpected error: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mirroracle – Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _signIn,
              child: _loading ? const CircularProgressIndicator() : const Text('Sign in'),
            ),
            TextButton(onPressed: _loading ? null : _signUp, child: const Text('Create account')),
          ],
        ),
      ),
    );
  }
}
