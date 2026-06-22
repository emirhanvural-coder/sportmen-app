import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox(); // 0 ise gösterme

    String text = count > 99 ? "99+" : "$count";

    return Container(
      // İç boşluğu azalttık
      padding: const EdgeInsets.all(3), 
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1.5), // Etrafına siyah kontur ekledik, daha okunaklı olur
      ),
      constraints: const BoxConstraints(
        minWidth: 16, // Genişliği küçülttük
        minHeight: 16, // Yüksekliği küçülttük
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9, // Yazı boyutunu küçülttük
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}