import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';

class ResultScreen extends StatelessWidget {
  final List<Map<String,Object>> quizResult;
  final List<Map<String,Object>> quizData;
  final VoidCallback onPressed;
  // final int originalOptionsPerQuestion;

  const ResultScreen(this.quizData,this.quizResult, this.onPressed,{super.key});

  int getScoreForQuestion(List<String> result) {
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> result_data = [];
    int i = 0;
    int total_marks=0;
    while (i < quizResult.length-1){
      bool correct=false;
      for (int y=0;y<(quizResult[i]["selection"] as List).cast<String>().length;y++){
        if ((quizData[i]["answer"] as List).cast<String>().contains((quizResult[i]["selection"] as List).cast<String>()[y]))
            {correct=true;
            }else{
          correct=false;
          break;
        }
    }
      (correct)?total_marks+=4:
    total_marks-=1;
      i++;
    }
    i=0;
    result_data.add(Container(
      // padding: EdgeInsets.all(120),
      alignment: Alignment.center,
      height: 400,
      child: MarksPanel(
        totalCorrectAnswers: total_marks,
        totalQuestions: (quizResult.length-1)*3,
      ),
    ));

    result_data.add(Container(
      alignment: Alignment.center,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: Icon(Icons.lock_reset_outlined),
        label: TextContainer("Restart Quiz", Colors.black, 30),
      ),
    ));

    while (i < quizResult.length-1) {
      Map<String, Object> resultDataset = quizResult[i];
      Map<String, Object> data = quizData[i];
      List<Widget> selections=[];
      int y=0;
      print(total_marks);
      while(y<((resultDataset["selection"] as List).cast<String>()).length) {
        if (y ==
            (((resultDataset["selection"] as List).cast<String>()).length) -
                1) {
          selections.add(
              TextContainer("Selection ${y + 1}:", Colors.green, 15));
        }
        else {
          selections.add(
              TextContainer("Selection ${y + 1}:", Colors.red, 15));
        }
        selections.add(TextContainer(
            ((resultDataset["selection"] as List).cast<String>())[y],
            Colors.white, 15));
        y++;
      }

      result_data.add(Container(
          margin: const EdgeInsets.all(20),
          width: double.infinity,
          child: IntrinsicHeight(child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                width: MediaQuery.of(context).size.width * 0.15, // 20% width
                color: Colors.blueGrey[700],
                  child: Center(child:TextContainer((i+1).toString(), Colors.white70, 20,fontWeight: FontWeight.bold,))

              ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.7, // 70% width
                  color: Colors.blueGrey[700],
                  padding: EdgeInsets.all(9),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextContainer("Quesation: ", Colors.white70, 20,fontWeight: FontWeight.bold,),
                      TextContainer(resultDataset["question"] as String, Colors.white70, 15),

                      TextContainer("Marks Obtained: ", Colors.white70, 18,fontWeight: FontWeight.bold,),
                      TextContainer(
                        "${(data["options"] as List).cast<String>().length -
                                (resultDataset["selection"] as List).cast<String>().length}",
                        Colors.white,
                        15,
                      ),
                      // TextContainer("Correct Answer: ${resultDataset["answer"] as String}", Colors.white70, 15),
                      TextContainer("Choices Record: ", Colors.white, 15),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: selections
                        ,)
                    ],

                  ),
                ),],
            )
      )
      )
      );
      i++;
    }
    result_data.add(SizedBox(height: 150 ,));
    print(result_data);

    return
      SingleChildScrollView(child:
        Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: result_data,
      )
    );
  }
}
