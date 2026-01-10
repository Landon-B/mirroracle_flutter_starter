import 'package:flutter/material.dart';

class StreakBar extends StatelessWidget {
  const StreakBar({
    super.key,
    required this.activeDates,
    required this.loading,
  });

  final Set<DateTime> activeDates;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final today = _dayOnly(DateTime.now());
    final days = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );
    final weeklyActiveDays = days.where(activeDates.contains).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2624),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF2D59C), width: 2),
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Text(
                    '$weeklyActiveDays',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((day) {
                final signedIn = activeDates.contains(day);
                return Column(
                  children: [
                    Text(
                      _dowLabel(day),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: signedIn
                            ? const Color(0xFFFFB9A8)
                            : const Color(0xFF3E3331),
                        shape: BoxShape.circle,
                      ),
                      child: signedIn
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _dowLabel(DateTime date) {
    const names = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return names[(date.weekday - 1) % 7];
  }

  DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
