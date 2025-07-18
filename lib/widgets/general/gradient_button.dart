import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback onPress;
  final double height;
  final double width;
  final double borderRadius;
  final String text;
  final double fontSize;
  final Color fontColor;
  final FontWeight fontWeight;

  const GradientButton({
    super.key,
    required this.onPress,
    this.height = 48.0,
    this.width = double.infinity,
    this.borderRadius = 10.0,
    this.text = '',
    this.fontSize = 16.0,
    this.fontColor = Colors.white,
    this.fontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: TextButton(
          onPressed: onPress,
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: fontColor,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }
}
