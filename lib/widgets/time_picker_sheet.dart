import 'package:flutter/material.dart';

class TimePickerSheet extends StatelessWidget {
  final Function(int) onTimeSet;

  const TimePickerSheet({super.key, required this.onTimeSet});

  @override
  Widget build(BuildContext context) {
    // Default start: 0
    final FixedExtentScrollController hCtrl =
        FixedExtentScrollController(initialItem: 0);
    final FixedExtentScrollController mCtrl =
        FixedExtentScrollController(initialItem: 0);
    final FixedExtentScrollController sCtrl =
        FixedExtentScrollController(initialItem: 0);

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text("Set Duration", textAlign: TextAlign.center),
      content: SizedBox(
        height: 200,
        width: 300,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildWheel(hCtrl, 24, "Hr"),
            const Text(":",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            _buildWheel(mCtrl, 60, "Min"),
            const Text(":",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            _buildWheel(sCtrl, 60, "Sec"),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel")),
        FilledButton(
          onPressed: () {
            int h = hCtrl.selectedItem;
            int m = mCtrl.selectedItem;
            int s = sCtrl.selectedItem;
            int total = (h * 3600) + (m * 60) + s;

            if (total > 0) {
              onTimeSet(total);
            }
            Navigator.pop(context);
          },
          child: const Text("Set Time"),
        ),
      ],
    );
  }

  Widget _buildWheel(
      FixedExtentScrollController ctrl, int count, String label) {
    return SizedBox(
      width: 60,
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 40,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.005,
        diameterRatio: 1.2,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            return Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Helper to format seconds into "1h 30m" string
String formatDuration(int seconds) {
  if (seconds == 0) return "";
  int h = seconds ~/ 3600;
  int m = (seconds % 3600) ~/ 60;
  if (h > 0) return "${h}h ${m}m";
  return "${m}m";
}
