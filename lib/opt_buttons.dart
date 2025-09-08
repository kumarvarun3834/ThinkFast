
import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';

class buttons_opt extends StatelessWidget {
  final VoidCallback onPressed;
  buttons_opt(this.opt,this.onPressed,this.quizResult,{super.key});
  // final String Q,A;
  final String opt;
  Map<String,Object> quizResult;
  Color colour=Colors.black;

  @override
  Widget build(BuildContext context) {
    (quizResult["selection"] as List).cast<String>().contains(opt)
        ?colour=Colors.red:colour=Colors.black;

    return Container(
        width: 350,
        child: OutlinedButton.icon(
            onPressed: () {
              List<String> selectionList = (quizResult["selection"] as List).cast<String>();
              if (!selectionList.contains(opt)) {
                selectionList.add(opt);
              } else {
                print("$opt already exists");
              }
              print(quizResult);
              onPressed();
            },
            style: OutlinedButton.styleFrom(

              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              backgroundColor: Colors.white10,
              foregroundColor: colour,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            label: TextContainer(opt, colour, 20)
        )
    );
  }
}