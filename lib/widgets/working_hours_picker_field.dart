import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// Ortak çalışma saatleri seçici — 7 gün için açık/kapalı + saat aralığı.
///
/// Döndürdüğü veri şekli generator'ların beklediğiyle birebir aynı:
/// `List<Map<String, String?>>` — {'day': 'Pazartesi', 'range': '09:00 - 19:00'}
/// Kapalı günler listeye 'range': null olarak eklenir; generator bunu
/// tabloda "Kapalı" olarak gösteriyor (bkz. shared_html_blocks.dart).
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

  @override
  void initState() {
    super.initState();
    final initial = widget.initialHours;
    if (initial != null) {
      for (final row in initial) {
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
    // İlk değeri de yukarı bildir ki form varsayılan saatlerle üretebilsin.
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
      ],
    );
  }
}
