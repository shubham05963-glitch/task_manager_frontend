import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  final Color color;
  final String headerText;
  final String descriptionText;
  final bool isCompleted;

  const TaskCard({
    super.key,
    required this.color,
    required this.headerText,
    required this.descriptionText,
    this.isCompleted = false,
  });

  /// Determine readable text color
  Color getTextColor() {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade400 : color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TITLE
          Text(
            headerText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isCompleted ? Colors.black54 : textColor,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),

          const SizedBox(height: 6),

          /// DESCRIPTION
          Text(
            descriptionText,
            style: TextStyle(
              fontSize: 14,
              color: isCompleted ? Colors.black45 : textColor.withOpacity(0.8),
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
