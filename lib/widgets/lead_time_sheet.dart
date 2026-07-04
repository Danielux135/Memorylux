import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

// sentinela para distinguir "canceló la hoja" de "eligió por defecto (null)"
class LeadTimeChoice {
  final int? minutes;

  const LeadTimeChoice(this.minutes);
}

// etiqueta legible de una antelación: "Solo a la hora exacta", "30 min antes"…
String leadTimeLabel(int? minutes, bool en, {String? defaultLabel}) {
  if (minutes == null) {
    return defaultLabel ?? (en ? 'Default' : 'Por defecto');
  }
  if (minutes == 0) return en ? 'Right on time only' : 'Solo a la hora exacta';
  final label = NotificationService.leadLabel(minutes, en);
  return en ? '$label before' : '$label antes';
}

// selector de antelación compartido entre ajustes y el editor de memorias;
// devuelve null si se cierra sin elegir, o la elección envuelta si se elige
Future<LeadTimeChoice?> pickLeadTime(
  BuildContext context, {
  required bool en,
  bool allowDefault = false,
  int? current,
}) {
  const presets = [0, 5, 10, 15, 30, 60, 120, 1440];
  return showModalBottomSheet<LeadTimeChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(en ? 'Warn me before…' : 'Avísame antes…',
                style: AppTheme.hand(
                    size: 24, color: Theme.of(ctx).colorScheme.onSurface)),
            if (allowDefault)
              ListTile(
                leading: const Icon(Icons.settings_suggest_outlined,
                    color: AppTheme.lux),
                title: Text(en
                    ? 'Default (from settings)'
                    : 'Por defecto (el de ajustes)'),
                selected: current == null,
                onTap: () => Navigator.pop(ctx, const LeadTimeChoice(null)),
              ),
            for (final m in presets)
              ListTile(
                leading: Icon(
                    m == 0 ? Icons.notifications_active : Icons.timer_outlined,
                    color: AppTheme.lux),
                title: Text(leadTimeLabel(m, en)),
                selected: current == m,
                onTap: () => Navigator.pop(ctx, LeadTimeChoice(m)),
              ),
            ListTile(
              leading: const Icon(Icons.tune, color: AppTheme.lux),
              title: Text(en ? 'Custom…' : 'Personalizado…'),
              onTap: () async {
                final custom = await _pickCustom(ctx, en);
                if (ctx.mounted && custom != null) {
                  Navigator.pop(ctx, LeadTimeChoice(custom));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

// diálogo de antelación personalizada: cantidad + unidad
Future<int?> _pickCustom(BuildContext context, bool en) {
  final controller = TextEditingController();
  var unit = 'min';
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(en ? 'Custom advance notice' : 'Antelación personalizada'),
        content: Row(
          children: [
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '20'),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: unit,
              items: [
                DropdownMenuItem(
                    value: 'min', child: Text(en ? 'minutes' : 'minutos')),
                DropdownMenuItem(
                    value: 'h', child: Text(en ? 'hours' : 'horas')),
                DropdownMenuItem(
                    value: 'd', child: Text(en ? 'days' : 'días')),
              ],
              onChanged: (v) => setState(() => unit = v ?? 'min'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(en ? 'Cancel' : 'Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n == null || n <= 0) return;
              final minutes = switch (unit) {
                'h' => n * 60,
                'd' => n * 1440,
                _ => n,
              };
              Navigator.pop(ctx, minutes);
            },
            child: Text(en ? 'OK' : 'Aceptar'),
          ),
        ],
      ),
    ),
  );
}
