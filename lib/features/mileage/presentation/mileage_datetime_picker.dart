import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class MileageDateTimePicker {
  Future<DateTime?> pick(BuildContext context, DateTime initialLocalDateTime);
}

class MaterialMileageDateTimePicker implements MileageDateTimePicker {
  const MaterialMileageDateTimePicker();

  @override
  Future<DateTime?> pick(BuildContext context, DateTime initialLocalDateTime) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialLocalDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialLocalDateTime),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }
}

final mileageDateTimePickerProvider = Provider<MileageDateTimePicker>((ref) {
  return const MaterialMileageDateTimePicker();
});
