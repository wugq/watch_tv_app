import 'package:flutter/material.dart';

class FavoriteButton extends StatelessWidget {
  final bool favorite;
  final VoidCallback onPressed;
  final Color? color;

  const FavoriteButton({
    super.key,
    required this.favorite,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
      onPressed: onPressed,
      icon: Icon(
        favorite ? Icons.star_rounded : Icons.star_outline_rounded,
        color: favorite ? Colors.amber : color,
      ),
    );
  }
}
