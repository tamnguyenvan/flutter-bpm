import 'package:flutter/material.dart';

class SuccessView extends StatelessWidget {
  const SuccessView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Done!",
          style: TextStyle(
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
