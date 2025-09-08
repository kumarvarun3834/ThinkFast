import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/ImageContainer.dart';

class  Main_Screen extends StatelessWidget {
  final VoidCallback onPressed;
  const Main_Screen({super.key,required this.onPressed});
  // Widget next;

  @override
  Widget build(BuildContext context) {
    // return Center(child: TextContainer("works", Colors.black, 50));
    return Center(child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        //   mainAxisSize: MainAxisSize.min,
        children: [
          ImageContainer("assets/images/quiz-logo.png",Color.fromARGB(
              128, 255, 255, 255),350,300),
          const SizedBox(height: 50,),
          TextContainer("Are you ready ?",Color.fromARGB(255, 255, 225, 0),30),
          const SizedBox(height: 25),

          OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(Icons.arrow_right_alt),
            label: TextContainer("Start Quiz", Colors.black, 30),
          )

        ]),
    );
  }
}
