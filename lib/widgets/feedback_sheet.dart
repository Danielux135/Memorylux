import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';

// formulario para enviar comentarios o reportar bugs sin registrarse
Future<void> showFeedbackSheet(BuildContext context) {
  // read, no watch: se llama desde un event handler, fuera del build
  final en = context.read<SettingsProvider>().settings.language == 'en';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      // deja sitio al teclado cuando está abierto
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _FeedbackForm(en: en),
    ),
  );
}

class _FeedbackForm extends StatefulWidget {
  final bool en;

  const _FeedbackForm({required this.en});

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  String _type = 'Comentario';
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);
    final result = await FeedbackService.send(
      type: _type,
      message: message,
      email: _emailController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.en
              ? 'Sent! Thank you for helping improve Memorylux 💛'
              : '¡Enviado! Gracias por ayudar a mejorar Memorylux 💛')));
    } else {
      // motivo real visible temporalmente para depurar el envío
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(widget.en
              ? 'Could not send: ${result.error}'
              : 'No se pudo enviar: ${result.error}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.en;
    final scheme = Theme.of(context).colorScheme;
    final types = <(String, String, IconData)>[
      ('Comentario', en ? 'Comment' : 'Comentario', Icons.chat_bubble_outline),
      ('Bug', en ? 'Bug' : 'Bug', Icons.bug_report_outlined),
      ('Idea', en ? 'Idea' : 'Idea', Icons.lightbulb_outline),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                  en ? 'Send feedback' : 'Enviar feedback',
                  style: AppTheme.hand(size: 26, color: scheme.onSurface)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final t in types)
                  ChoiceChip(
                    avatar: Icon(t.$3, size: 18),
                    label: Text(t.$2),
                    selected: _type == t.$1,
                    onSelected: (_) => setState(() => _type = t.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: en
                    ? 'Tell me what happened or what you would improve…'
                    : 'Cuéntame qué ha pasado o qué mejorarías…',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: en
                    ? 'Your email (optional, to reply to you)'
                    : 'Tu correo (opcional, para responderte)',
                prefixIcon: const Icon(Icons.alternate_email),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_sending
                    ? (en ? 'Sending…' : 'Enviando…')
                    : (en ? 'Send' : 'Enviar')),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                en
                    ? 'Goes straight to the developer. No account needed.'
                    : 'Le llega directamente al desarrollador. Sin cuentas ni registros.',
                style: AppTheme.ui(
                    size: 12,
                    color: scheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
