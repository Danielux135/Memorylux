import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/memory.dart';
import '../providers/memory_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/lead_time_sheet.dart';
import '../services/auth_service.dart';
import '../services/audio_store.dart';
import '../services/image_store.dart';
import '../services/monetization_service.dart';
import '../theme/app_theme.dart';
import '../l10n/lang.dart';

// editor completo de una memoria: texto, checklist, color o foto custom,
// fecha, repetición, prioridad y etiquetas
class MemoryEditor extends StatefulWidget {
  final Memory? memory; // null = crear nueva

  const MemoryEditor({super.key, this.memory});

  static Future<void> open(BuildContext context, {Memory? memory}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemoryEditor(memory: memory)),
    );
  }

  @override
  State<MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<MemoryEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tagInput;
  final _checkInput = TextEditingController();

  late String _color;
  String? _imagePath;
  late List<String> _tags;
  late List<ChecklistItem> _checklist;
  DateTime? _dueDate;
  bool _hasTime = false;
  late Recurrence _recurrence;
  late MemoryPriority _priority;
  late BoardZone _zone;
  int? _minutesBefore; // antelación del aviso; null usa la de ajustes
  String? _alarmSound; // null usa ajustes; 'alarm' suena; 'silent' no suena

  Memory? get _editing => widget.memory;

  @override
  void initState() {
    super.initState();
    final m = _editing;
    _title = TextEditingController(text: m?.title ?? '');
    _body = TextEditingController(text: m?.body ?? '');
    _tagInput = TextEditingController();
    _color = m?.color ?? AppTheme.noteColors.first;
    _imagePath = m?.imagePath;
    _tags = List.of(m?.tags ?? []);
    _checklist = (m?.checklist ?? [])
        .map((c) => ChecklistItem(text: c.text, done: c.done))
        .toList();
    _dueDate = m?.dueDate;
    _hasTime = m?.hasTime ?? false;
    _recurrence = m?.recurrence ?? const Recurrence();
    _priority = m?.priority ?? MemoryPriority.normal;
    _zone = m?.zone ?? BoardZone.today;
    _minutesBefore = m?.notificationMinutesBefore;
    _alarmSound = m?.alarmSound;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagInput.dispose();
    _checkInput.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.pick('Escribe un título para tu recuerdo',
                'Write a title for your memory'))),
      );
      return;
    }
    final provider = context.read<MemoryProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final userId = context.read<AuthService>().userId;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_editing != null) {
      await provider.updateMemory(
        _editing!.copyWith(
          title: title,
          body: _body.text.trim(),
          checklist: _checklist,
          color: _color,
          imagePath: _imagePath,
          tags: _tags,
          dueDate: _dueDate,
          hasTime: _hasTime,
          recurrence: _recurrence,
          priority: _priority,
          zone: _zone,
          notificationMinutesBefore: _minutesBefore,
          alarmSound: _alarmSound,
        ),
        settings,
      );
    } else {
      await provider.addMemory(
        Memory(
          userId: userId,
          title: title,
          body: _body.text.trim(),
          checklist: _checklist,
          color: _color,
          imagePath: _imagePath,
          tags: _tags,
          dueDate: _dueDate,
          hasTime: _hasTime,
          recurrence: _recurrence,
          priority: _priority,
          zone: _zone,
          notificationMinutesBefore: _minutesBefore,
          alarmSound: _alarmSound,
        ),
        settings,
      );
    }
    if (navigator.mounted) navigator.pop();
    messenger.showSnackBar(
      SnackBar(
          content: Text(context.pick('“$title” guardado en tu panel',
              '“$title” saved to your board'))),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    setState(() {
      final old = _dueDate;
      _dueDate = DateTime(
          date.year,
          date.month,
          date.day,
          _hasTime && old != null ? old.hour : 9,
          _hasTime && old != null ? old.minute : 0);
    });
  }

  Future<void> _pickTime() async {
    if (_dueDate == null) await _pickDate();
    if (_dueDate == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate!),
    );
    if (time == null) return;
    setState(() {
      _dueDate = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day,
          time.hour, time.minute);
      _hasTime = true;
    });
  }

  // selector de fondo custom: subir foto nueva o elegir de las ya subidas.
  // en Android es una funcion premium exclusiva de la app de pago
  Future<void> _pickImage() async {
    final monetization = context.read<MonetizationService>();
    if (monetization.isAndroid && !monetization.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.pick(
            'Las fotos custom son una función premium. Consíguela en la versión de pago.',
            'Custom photos are a premium feature. Get it in the paid version.',
          )),
        ),
      );
      return;
    }

    final gallery = await ImageStore.gallery();
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.add_photo_alternate, color: AppTheme.lux),
              title: Text(
                  context.pick('Subir una foto nueva', 'Upload a new photo')),
              subtitle: Text(context.pick(
                  'Tu anime, tu mascota, lo que quieras de fondo',
                  'Your anime, your pet, whatever you want as background')),
              onTap: () async {
                final path = await ImageStore.pickAndStore();
                if (ctx.mounted) Navigator.pop(ctx, path);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.layers_clear),
                title: Text(context.pick('Quitar la foto', 'Remove photo')),
                onTap: () => Navigator.pop(ctx, ''),
              ),
            if (gallery.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                    context.pick('Tus fotos subidas', 'Your uploaded photos'),
                    style: AppTheme.hand(
                        size: 22, color: Theme.of(ctx).colorScheme.onSurface)),
              ),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: gallery.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.pop(ctx, gallery[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(gallery[i]),
                          width: 96, height: 96, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() => _imagePath = result.isEmpty ? null : result);
  }

  Future<void> _editRecurrence() async {
    final picked = await showModalBottomSheet<Recurrence>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _RecurrenceSheet(current: _recurrence),
    );
    if (picked != null) setState(() => _recurrence = picked);
  }

  void _addTag() {
    final tag = _tagInput.text.trim().replaceAll('#', '').toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagInput.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final en = context.isEn;
    final dateLabel = _dueDate == null
        ? context.pick('Sin fecha', 'No date')
        : DateFormat('EEE d MMM yyyy', en ? 'en_US' : 'es').format(_dueDate!);
    final timeLabel = _hasTime && _dueDate != null
        ? DateFormat('HH:mm').format(_dueDate!)
        : context.pick('Sin hora', 'No time');

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null
            ? context.pick('Nuevo recuerdo', 'New memory')
            : context.pick('Editar recuerdo', 'Edit memory')),
        actions: [
          if (_editing != null)
            IconButton(
              tooltip: context.pick('Borrar', 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final provider = context.read<MemoryProvider>();
                final settings = context.read<SettingsProvider>().settings;
                final navigator = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.pick(
                        '¿Borrar este recuerdo?', 'Delete this memory?')),
                    content: Text(context.pick(
                        'No se puede deshacer.', 'This cannot be undone.')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(context.pick('Cancelar', 'Cancel'))),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(context.pick('Borrar', 'Delete'))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await provider.deleteMemory(_editing!.id, settings: settings);
                  if (navigator.mounted) navigator.pop();
                }
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(context.pick('Guardar', 'Save')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            style: AppTheme.hand(size: 28, color: scheme.onSurface),
            decoration: InputDecoration(
                hintText: context.pick('¿Qué no quieres olvidar?',
                    'What do you not want to forget?')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 3,
            decoration: InputDecoration(
                hintText:
                    context.pick('Detalles (opcional)', 'Details (optional)')),
          ),
          const SizedBox(height: 20),

          // aspecto del post-it: color de papel o foto propia
          Text(context.pick('Aspecto', 'Appearance'),
              style: AppTheme.hand(size: 24, color: scheme.onSurface)),
          const SizedBox(height: 8),
          Row(
            children: [
              ...AppTheme.noteColors.map((hex) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _color = hex;
                        _imagePath = null;
                      }),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.noteColor(hex),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _color == hex && _imagePath == null
                                ? AppTheme.lux
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  )),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _imagePath != null ? AppTheme.lux : scheme.outline,
                      width: _imagePath != null ? 3 : 1,
                    ),
                    image: _imagePath != null && File(_imagePath!).existsSync()
                        ? DecorationImage(
                            image: FileImage(File(_imagePath!)),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imagePath == null
                      ? const Icon(Icons.add_photo_alternate, size: 20)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // cuándo
          Text(context.pick('Cuándo', 'When'),
              style: AppTheme.hand(size: 24, color: scheme.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.event, size: 16),
                label: Text(dateLabel),
                onPressed: _pickDate,
              ),
              ActionChip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(timeLabel),
                onPressed: _pickTime,
              ),
              ActionChip(
                avatar: const Icon(Icons.repeat, size: 16),
                label: Text(_recurrence.isNone
                    ? context.pick('No se repite', 'Does not repeat')
                    : _recurrence.labelFor(en)),
                onPressed: _editRecurrence,
              ),
              if (_dueDate != null && _hasTime)
                ActionChip(
                  avatar: const Icon(Icons.notifications_active, size: 16),
                  label: Text(
                      '${context.pick('Aviso', 'Alert')}: ${leadTimeLabel(_minutesBefore, en, defaultLabel: context.pick('por defecto', 'default'))}'),
                  onPressed: () async {
                    final choice = await pickLeadTime(context,
                        en: en, allowDefault: true, current: _minutesBefore);
                    if (choice != null) {
                      setState(() => _minutesBefore = choice.minutes);
                    }
                  },
                ),
              if (_dueDate != null && _hasTime)
                ActionChip(
                  avatar: const Icon(Icons.volume_up, size: 16),
                  label: Text(
                    '${context.pick('Sonido', 'Sound')}: ${_alarmSoundLabel(context, _alarmSound)}',
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final addedSoundMessage = context.pick(
                      'Sonido "{name}" añadido a esta alarma',
                      'Sound "{name}" added to this alarm',
                    );
                    final choice = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.settings),
                              title: Text(context.pick(
                                  'Usar sonido por defecto',
                                  'Use default sound')),
                              onTap: () => Navigator.pop(ctx, 'default'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.notifications_active),
                              title: const Text('Alarm'),
                              onTap: () => Navigator.pop(ctx, 'alarm'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.audio_file),
                              title: Text(context.pick(
                                  'Elegir audio...', 'Choose audio...')),
                              onTap: () => Navigator.pop(ctx, 'pick'),
                            ),
                            ListTile(
                              leading: const Icon(Icons.volume_off),
                              title: Text(context.pick('Silencio', 'Silent')),
                              onTap: () => Navigator.pop(ctx, 'silent'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (choice == null) return;
                    if (choice == 'default') {
                      setState(() => _alarmSound = null);
                    } else if (choice == 'pick') {
                      final audio = await AudioStore.pickAndStore();
                      if (audio == null || !mounted) return;
                      setState(() => _alarmSound = audio.value);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            addedSoundMessage.replaceAll('{name}', audio.name),
                          ),
                        ),
                      );
                    } else {
                      setState(() => _alarmSound = choice);
                    }
                  },
                ),
              if (_dueDate != null)
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 16),
                  label: Text(context.pick('Quitar fecha', 'Remove date')),
                  onPressed: () => setState(() {
                    _dueDate = null;
                    _hasTime = false;
                    _recurrence = const Recurrence();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // insistencia
          Text(context.pick('Insistencia', 'Persistence'),
              style: AppTheme.hand(size: 24, color: scheme.onSurface)),
          const SizedBox(height: 8),
          SegmentedButton<MemoryPriority>(
            segments: [
              ButtonSegment(
                  value: MemoryPriority.normal,
                  icon: const Icon(Icons.notifications_none),
                  label: Text(context.pick('Normal', 'Normal'))),
              ButtonSegment(
                  value: MemoryPriority.important,
                  icon: const Icon(Icons.push_pin),
                  label: Text(context.pick('Importante', 'Important'))),
              ButtonSegment(
                  value: MemoryPriority.persistent,
                  icon: const Icon(Icons.local_fire_department),
                  label: Text(context.pick('Persistente', 'Persistent'))),
            ],
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              switch (_priority) {
                MemoryPriority.normal => context.pick('Te avisa una vez y ya.',
                    'Notifies you once and that\'s it.'),
                MemoryPriority.important => context.pick(
                    'Reavisa una vez más si lo ignoras.',
                    'Reminds you once more if you ignore it.'),
                MemoryPriority.persistent => context.pick(
                    'No desaparece del panel y reavisa hasta que lo resuelvas.',
                    'Stays on the board and keeps reminding you until you resolve it.'),
              },
              style: AppTheme.ui(
                  size: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 20),

          // zona del tablero
          Text(context.pick('Zona del panel', 'Board zone'),
              style: AppTheme.hand(size: 24, color: scheme.onSurface)),
          const SizedBox(height: 8),
          SegmentedButton<BoardZone>(
            segments: [
              ButtonSegment(
                  value: BoardZone.today,
                  label: Text(context.pick('Hoy', 'Today'))),
              ButtonSegment(
                  value: BoardZone.dontForget,
                  label: Text(context.pick('No olvidar', 'Don\'t forget'))),
              ButtonSegment(
                  value: BoardZone.waiting,
                  label: Text(context.pick('En espera', 'Waiting'))),
            ],
            selected: {_zone},
            onSelectionChanged: (s) => setState(() => _zone = s.first),
          ),
          const SizedBox(height: 20),

          // checklist
          Text(context.pick('Checklist', 'Checklist'),
              style: AppTheme.hand(size: 24, color: scheme.onSurface)),
          ..._checklist.asMap().entries.map((entry) => CheckboxListTile(
                value: entry.value.done,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(entry.value.text,
                    style: TextStyle(
                        decoration: entry.value.done
                            ? TextDecoration.lineThrough
                            : null)),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      setState(() => _checklist.removeAt(entry.key)),
                ),
                onChanged: (v) => setState(() => entry.value.done = v ?? false),
              )),
          TextField(
            controller: _checkInput,
            decoration: InputDecoration(
              hintText: context.pick(
                  'Añadir paso y pulsar Enter', 'Add a step and press Enter'),
              prefixIcon: const Icon(Icons.add),
            ),
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              setState(() {
                _checklist.add(ChecklistItem(text: v.trim()));
                _checkInput.clear();
              });
            },
          ),
          const SizedBox(height: 20),

          // etiquetas
          Text(context.pick('Etiquetas', 'Tags'),
              style: AppTheme.hand(size: 24, color: scheme.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tags.map((t) => Chip(
                    label: Text('#$t'),
                    onDeleted: () => setState(() => _tags.remove(t)),
                  )),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _tagInput,
                  decoration: InputDecoration(
                      hintText: context.pick('#etiqueta', '#tag'),
                      isDense: true),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

String _alarmSoundLabel(BuildContext context, String? sound) {
  return AudioStore.labelFor(sound, en: context.isEn);
}

// hoja para elegir la repetición
class _RecurrenceSheet extends StatefulWidget {
  final Recurrence current;

  const _RecurrenceSheet({required this.current});

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  late RecurrenceType _type;
  late List<int> _weekdays;
  late int _everyHours;
  DateTime? _until;

  @override
  void initState() {
    super.initState();
    _type = widget.current.type;
    _weekdays = List.of(widget.current.weekdays);
    _everyHours = widget.current.everyHours;
    _until = widget.current.until;
  }

  @override
  Widget build(BuildContext context) {
    final en = context.isEn;
    final dayNames = en
        ? ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su']
        : ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.pick('Repetir', 'Repeat'),
                style: AppTheme.hand(
                    size: 26, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, type) in [
                  (context.pick('Nunca', 'Never'), RecurrenceType.none),
                  (context.pick('Cada día', 'Every day'), RecurrenceType.daily),
                  (
                    context.pick('Cada semana', 'Every week'),
                    RecurrenceType.weekly
                  ),
                  (
                    context.pick('Cada mes', 'Every month'),
                    RecurrenceType.monthly
                  ),
                  (
                    context.pick('Días concretos', 'Specific days'),
                    RecurrenceType.weekdays
                  ),
                  (
                    context.pick('Cada X horas', 'Every X hours'),
                    RecurrenceType.everyXHours
                  ),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            if (_type == RecurrenceType.weekdays) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  return FilterChip(
                    label: Text(dayNames[i]),
                    selected: _weekdays.contains(day),
                    onSelected: (v) => setState(() {
                      v ? _weekdays.add(day) : _weekdays.remove(day);
                    }),
                  );
                }),
              ),
            ],
            if (_type == RecurrenceType.everyXHours) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(context.pick('Cada', 'Every')),
                  Expanded(
                    child: Slider(
                      value: _everyHours.toDouble().clamp(1, 24),
                      min: 1,
                      max: 24,
                      divisions: 23,
                      label: '$_everyHours h',
                      onChanged: (v) => setState(() => _everyHours = v.round()),
                    ),
                  ),
                  Text('$_everyHours h'),
                ],
              ),
            ],
            if (_type != RecurrenceType.none) ...[
              const SizedBox(height: 8),
              ActionChip(
                avatar: const Icon(Icons.event_busy, size: 16),
                label: Text(_until == null
                    ? context.pick('Repetir para siempre', 'Repeat forever')
                    : context.pick(
                        'Hasta ${DateFormat('d MMM yyyy', 'es').format(_until!)}',
                        'Until ${DateFormat('d MMM yyyy', 'en_US').format(_until!)}')),
                onPressed: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _until ?? now.add(const Duration(days: 30)),
                    firstDate: now,
                    lastDate: DateTime(now.year + 5),
                  );
                  setState(() => _until = date);
                },
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  Recurrence(
                    type: _type,
                    weekdays: _weekdays..sort(),
                    everyHours: _everyHours,
                    until: _until,
                  ),
                ),
                child: Text(context.pick('Aplicar', 'Apply')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
