import 'package:flutter/material.dart';

class CustomLoading extends StatelessWidget {
  final double size;
  
  const CustomLoading({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/loading.gif',
        width: size,
        height: size,
      ),
    );
  }
}