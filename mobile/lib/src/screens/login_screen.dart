import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_theme.dart';
import '../models.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onSignedIn});
  final ApiClient api;
  final ValueChanged<AppUser?> onSignedIn;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  @override
  void dispose() { _identifier.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try { widget.onSignedIn(await widget.api.login(_identifier.text, _password.text)); }
    on ApiException catch (error) { if (mounted) setState(() => _error = error.message); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(child: Center(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(alignment: Alignment.centerRight, child: Container(width: 62, height: 62, decoration: BoxDecoration(color: SarehnyColors.primary, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 29))),
                const SizedBox(height: 28),
                Text('أهلًا بعودتك', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('سجّل دخولك بحساب صراحة نفسه لقراءة رسائلك.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SarehnyColors.muted)),
                const SizedBox(height: 28),
                TextFormField(controller: _identifier, textDirection: TextDirection.ltr, textAlign: TextAlign.left, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.username, AutofillHints.email], decoration: const InputDecoration(labelText: 'البريد الإلكتروني أو اسم المستخدم', prefixIcon: Icon(Icons.alternate_email_rounded)), validator: (value) => value == null || value.trim().isEmpty ? 'أدخل بريدك أو اسم المستخدم.' : null),
                const SizedBox(height: 14),
                TextFormField(controller: _password, textDirection: TextDirection.ltr, textAlign: TextAlign.left, obscureText: !_showPassword, autofillHints: const [AutofillHints.password], onFieldSubmitted: (_) => _login(), decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.key_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))), validator: (value) => value == null || value.isEmpty ? 'أدخل كلمة المرور.' : null),
                if (_error != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF0F1), borderRadius: BorderRadius.circular(14)), child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SarehnyColors.danger)))],
                const SizedBox(height: 22),
                FilledButton(onPressed: _busy ? null : _login, child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('تسجيل الدخول')),
                const SizedBox(height: 20),
                Center(child: Text('تسجيل آمن · بياناتك تبقى على موقع صراحة', style: Theme.of(context).textTheme.bodySmall)),
              ]),
            )),
          ))),
        ),
      );
}
