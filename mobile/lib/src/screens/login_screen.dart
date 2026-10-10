import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../app_theme.dart';
import '../models.dart';
import '../site_browser.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onSignedIn});
  final ApiClient api;
  final ValueChanged<AppUser?> onSignedIn;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _registering = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _openSiteHome() async {
    try {
      await SiteBrowser.open(widget.api, SitePagePaths.home);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'تعذّر فتح موقع صراحة.');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _registering
          ? await widget.api.register(
              name: _name.text.trim(),
              username: _username.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : await widget.api.login(_identifier.text, _password.text);
      widget.onSignedIn(user);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'أدخل كلمة المرور.';
    if (_registering && value.length < 8) return 'كلمة المرور يجب ألا تقل عن ٨ أحرف.';
    return null;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Theme.of(context).extension<SarehnyPalette>()!.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.lock_outline_rounded,
                                color: Theme.of(context).colorScheme.onPrimary, size: 29),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _registering ? 'أنشئ حساب صراحة' : 'أهلًا بعودتك',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _registering
                              ? 'أنشئ حساب اختبار أو حسابك على بيئة صراحة التي اخترتها.'
                              : 'سجّل دخولك بحساب صراحة نفسه لقراءة رسائلك.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).extension<SarehnyPalette>()!.muted),
                        ),
                        const SizedBox(height: 28),
                        if (_registering) ...[
                          TextFormField(
                            controller: _name,
                            maxLength: 80,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'الاسم الظاهر',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) => value == null || value.trim().length < 2
                                ? 'اكتب اسمًا من حرفين على الأقل.'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _username,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                            ],
                            maxLength: 30,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixText: '@ ',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (value) => value == null ||
                                    !RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(value.trim())
                                ? 'استخدم ٣–٣٠ حرفًا إنجليزيًا أو رقمًا أو _.'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _email,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) => value == null ||
                                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                        .hasMatch(value.trim())
                                ? 'أدخل بريدًا إلكترونيًا صالحًا.'
                                : null,
                          ),
                        ] else
                          TextFormField(
                            controller: _identifier,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني أو اسم المستخدم',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'أدخل بريدك أو اسم المستخدم.'
                                : null,
                          ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            _registering ? AutofillHints.newPassword : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.key_rounded),
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).extension<SarehnyPalette>()!.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Theme.of(context).extension<SarehnyPalette>()!.danger),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                                )
                              : Text(_registering ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _registering = !_registering;
                                    _error = null;
                                    _formKey.currentState?.reset();
                                  }),
                          child: Text(_registering
                              ? 'لديك حساب بالفعل؟ سجّل الدخول'
                              : 'ليس لديك حساب؟ أنشئ حسابًا'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _openSiteHome,
                          icon: const Icon(Icons.language_rounded),
                          label: const Text('تصفح موقع صراحة'),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'اتصل فقط ببيئة الاختبار التي ضبطتها في إعداد التطبيق.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
