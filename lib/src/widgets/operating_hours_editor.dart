import 'package:flutter/material.dart';

import '../services/management_api.dart';

class OperatingHoursEditor extends StatefulWidget {
  const OperatingHoursEditor({
    super.key,
    required this.api,
    required this.restaurantId,
    required this.initialHours,
  });

  final ManagementApi api;
  final String restaurantId;
  final List<Map<String, dynamic>> initialHours;

  @override
  State<OperatingHoursEditor> createState() => _OperatingHoursEditorState();
}

class _OperatingHoursEditorState extends State<OperatingHoursEditor> {
  static const _days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  late final List<_DayHours> _hours = List.generate(7, (index) {
    final existing = widget.initialHours.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['dayOfWeek'] == index,
          orElse: () => null,
        );
    return _DayHours(
      dayOfWeek: index,
      isClosed: existing?['isClosed'] == true,
      opensAt: existing?['opensAt']?.toString() ?? '09:00',
      closesAt: existing?['closesAt']?.toString() ?? '22:00',
    );
  });

  bool _saving = false;

  Future<void> _pickTime(_DayHours day, bool opening) async {
    final source = opening ? day.opensAt : day.closesAt;
    final parts = source.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      ),
    );
    if (selected == null) return;
    final value = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (opening) {
        day.opensAt = value;
      } else {
        day.closesAt = value;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.updateOperatingHours(
        restaurantId: widget.restaurantId,
        hours: _hours
            .map((day) => {
                  'dayOfWeek': day.dayOfWeek,
                  'isClosed': day.isClosed,
                  'opensAt': day.isClosed ? null : day.opensAt,
                  'closesAt': day.isClosed ? null : day.closesAt,
                })
            .toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Çalışma saatleri'),
      content: SizedBox(
        width: 620,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _hours.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final day = _hours[index];
            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                SizedBox(width: 110, child: Text(_days[index])),
                FilterChip(
                  selected: day.isClosed,
                  label: const Text('Kapalı'),
                  onSelected: (value) => setState(() => day.isClosed = value),
                ),
                OutlinedButton(
                  onPressed: day.isClosed ? null : () => _pickTime(day, true),
                  child: Text(day.opensAt),
                ),
                const Text('—'),
                OutlinedButton(
                  onPressed: day.isClosed ? null : () => _pickTime(day, false),
                  child: Text(day.closesAt),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _DayHours {
  _DayHours({
    required this.dayOfWeek,
    required this.isClosed,
    required this.opensAt,
    required this.closesAt,
  });

  final int dayOfWeek;
  bool isClosed;
  String opensAt;
  String closesAt;
}
