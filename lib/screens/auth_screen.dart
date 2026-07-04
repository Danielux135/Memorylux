import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../l10n/lang.dart';

// entrada a la app: un post-it gigante sobre la mesa
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isLogin = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    if (_isLogin) {
      await auth.signIn(_email.text.trim(), _password.text);
    } else {
      await auth.signUp(_email.text.trim(), _password.text, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/logo/memorylux_logo.svg',
                  height: 96,
                ),
                const SizedBox(height: 8),
                Text('Memorylux',
                    style: AppTheme.hand(size: 52, color: scheme.onSurface)),
                Text(
                  context.pick(
                      'Para gente que se olvida de cosas pequeñas\npero importantes.',
                      'For people who forget small\nbut important things.'),
                  textAlign: TextAlign.center,
                  style: AppTheme.ui(
                      size: 14,
                      color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 28),
                Transform.rotate(
                  angle: -0.012,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.noteColor('#FFE082'),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(3, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.lux,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.lux.withValues(alpha: 0.7),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        if (!_isLogin) ...[
                          _paperField(_name,
                              context.pick('Tu nombre', 'Your name'), Icons.person),
                          const SizedBox(height: 12),
                        ],
                        _paperField(
                            _email, context.pick('Correo', 'Email'), Icons.mail,
                            keyboard: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _paperField(_password,
                            context.pick('Contraseña', 'Password'), Icons.lock,
                            obscure: true),
                        if (auth.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              auth.error!,
                              style: AppTheme.ui(
                                  size: 13,
                                  color: const Color(0xFFB71C1C),
                                  weight: FontWeight.w700),
                            ),
                          ),
                        if (!auth.firebaseAvailable)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              context.pick(
                                  'Firebase no está activo aquí. Puedes usar Memorylux en modo local sin sincronización.',
                                  'Firebase is not active here. You can use Memorylux in local mode without sync.'),
                              textAlign: TextAlign.center,
                              style: AppTheme.ui(
                                size: 12,
                                color: const Color(0xFF2B2118)
                                    .withValues(alpha: 0.72),
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2B2118),
                              foregroundColor: AppTheme.noteColor('#FFE082'),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: auth.isLoading ? null : _submit,
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(_isLogin
                                    ? context.pick('Entrar', 'Sign in')
                                    : context.pick('Crear cuenta', 'Create account')),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2B2118),
                              side: BorderSide(
                                color: const Color(0xFF2B2118)
                                    .withValues(alpha: 0.35),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: auth.isLoading
                                ? null
                                : () => context
                                    .read<AuthService>()
                                    .continueOffline(),
                            icon: const Icon(Icons.offline_bolt),
                            label: Text(context.pick(
                                'Entrar sin sincronización', 'Continue without sync')),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            _isLogin
                                ? context.pick('¿Primera vez? Crea tu cuenta',
                                    'First time? Create your account')
                                : context.pick(
                                    'Ya tengo cuenta', 'I already have an account'),
                            style: AppTheme.ui(
                                size: 13,
                                color: const Color(0xFF2B2118),
                                weight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.pick(
                      'Tus notas no se pierden. Tus recordatorios no desaparecen.',
                      'Your notes don\'t get lost. Your reminders don\'t disappear.'),
                  textAlign: TextAlign.center,
                  style: AppTheme.hand(
                      size: 20,
                      color: scheme.onSurface.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paperField(TextEditingController controller, String hint, IconData icon,
      {bool obscure = false, TextInputType? keyboard}) {
    const ink = Color(0xFF2B2118);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: ink.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: ink.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.55),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ink.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ink, width: 2),
        ),
      ),
    );
  }
}
