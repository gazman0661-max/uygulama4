import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../templates/html/shared_html_blocks.dart' show kDefaultBusinessTimeZone;

class WorkingHoursPickerField extends StatefulWidget {
  const WorkingHoursPickerField({
    super.key,
    required this.onChanged,
    this.label = 'Çalışma Saatleri',
    this.initialHours,
  });

  final String label;
  final List<Map<String, String?>>? initialHours;
  final ValueChanged<List<Map<String, String?>>> onChanged;

  static const timeZones = <(String, String)>[
    ('Europe/Istanbul', 'İstanbul (Türkiye)'),
    ('Asia/Nicosia', 'Lefkoşa (KKTC)'),
    ('Europe/London', 'London'),
    ('Europe/Berlin', 'Berlin'),
    ('Europe/Paris', 'Paris'),
    ('Europe/Amsterdam', 'Amsterdam'),
    ('Asia/Baku', 'Bakü'),
    ('Asia/Dubai', 'Dubai'),
    ('America/New_York', 'New York'),
    ('America/Chicago', 'Chicago'),
    ('America/Los_Angeles', 'Los Angeles'),
  ];

  static const days = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];

  @override
  State<WorkingHoursPickerField> createState() => _WorkingHoursPickerFieldState();
}

class _DayState {
  bool open;
  TimeOfDay start;
  TimeOfDay end;
  _DayState({required this.open, required this.start, required this.end});
}

class _WorkingHoursPickerFieldState extends State<WorkingHoursPickerField> {
  late final Map<String, _DayState> _days = {
    for (final d in WorkingHoursPickerField.days)
      d: _DayState(
        open: !(d == 'Pazar'),
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 19, minute: 0),
      ),
  };

  String _tz = kDefaultBusinessTimeZone;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialHours;
    if (initial != null) {
      for (final row in initial) {
        final savedTz = row['tz'];
        if (savedTz != null &&
            WorkingHoursPickerField.timeZones.any((z) => z.$1 == savedTz)) {
          _tz = savedTz;
        }
        final day = row['day'];
        final range = row['range'];
        if (day == null || !_days.containsKey(day)) continue;
        if (range == null) {
          _days[day]!.open = false;
        } else {
          final parts = range.split('-').map((p) => p.trim()).toList();
          if (parts.length == 2) {
            _days[day]!
              ..open = true
              ..start = _parseTime(parts[0])
              ..end = _parseTime(parts[1]);
          }
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _emit() {
    final result = WorkingHoursPickerField.days.map((d) {
      final state = _days[d]!;
      return <String, String?>{
        'day': d,
        'range': state.open ? '${_fmt(state.start)} - ${_fmt(state.end)}' : null,
        'tz': _tz,
      };
    }).toList();
    widget.onChanged(result);
  }

  Future<void> _pickTime(String day, bool isStart) async {
    final state = _days[day]!;
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? state.start : state.end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        state.start = picked;
      } else {
        state.end = picked;
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, widget.label), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final day in WorkingHoursPickerField.days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(t(context, day), style: const TextStyle(fontSize: 13)),
                ),
                Switch(
                  value: _days[day]!.open,
                  onChanged: (v) {
                    setState(() => _days[day]!.open = v);
                    _emit();
                  },
                ),
                if (_days[day]!.open) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(day, true),
                      child: Text(_fmt(_days[day]!.start)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(t(context, '-')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(day, false),
                      child: Text(_fmt(_days[day]!.end)),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(t(context, 'Kapalı'), style: const TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(t(context, 'Saat Dilimi'), style: const TextStyle(fontSize: 13)),
        DropdownButton<String>(
          isExpanded: true,
          value: _tz,
          items: [
            for (final z in WorkingHoursPickerField.timeZones)
              DropdownMenuItem(value: z.$1, child: Text(t(context, z.$2))),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _tz = v);
            _emit();
          },
        ),
        Text(
          t(context, 'Şu An Açık bilgisi bu saat dilimine göre gösterilir.'),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
