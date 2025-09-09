import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/opt_buttons.dart';

class Quesations extends StatefulWidget {
  final List<Map<String, Object>> dataSet;
  final List<Map<String, Object>> quizResult;
  final void Function(String) onStateChange;

  Quesations(this.dataSet, this.quizResult,{
    required this.onStateChange,
    super.key,
  });

  @override
  State<Quesations> createState() => _Quesations();
}

class _Quesations extends State<Quesations> {
  late List<Map<String, Object>> dataSet;
  late List<Map<String, Object>> quizResult;

  int i = 0;

  @override
  void initState() {
    super.initState();
    dataSet = widget.dataSet;
    quizResult = widget.quizResult;
    // current_state = widget.currState;
    currentData = dataSet[i];
    quizResult[i]["question"]=dataSet[i]["question"]!;
    quizResult[i]["answer"]=dataSet[i]["answer"]!;
  }
  Map<String, Object> currentData={};
  void switchToResultScreen() {
    widget.onStateChange("result_screen");
  }

  void switchState() {
    setState(() {
      if (i < dataSet.length - 1 ) {
        currentData = dataSet[i];
        quizResult[i]["question"]=dataSet[i]["question"]!;
        quizResult[i]["answer"]=dataSet[i]["answer"]!;
        // currentData = dataSet[i];
        // quizResult[i]["question"]=dataSet[i]["question"]!;
        // quizResult[i]["answer"]=dataSet[i]["answer"]!;
      // } else if (i == dataSet.length - 1){
      //   switchToResultScreen();
      }
    });
  }

  List<Widget> buttons_Data(Map<String, Object> dataset) {
    List<Widget> database = [];
    List<String> options = dataset["options"] as List<String>;
    // String answer = dataset["answer"] as String;
    for (var option in options) {
      database.add(
        buttons_opt(option, switchState , quizResult[i]));
    }
    return database;
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
        title: 'Custom AppBar',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: Scaffold(
            appBar: AppBar(
              titleSpacing: 0, // so title sits right after menu button
              title: const Text("My App"),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Scaffold.of(context).openDrawer(); // open sidebar
                  },
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // red button
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      switchToResultScreen();
                      // action here
                    },
                    child: const Text(
                      "SUBMIT",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

        // drawer: Drawer(
        //   child: ListView(
        //     padding: EdgeInsets.zero,
        //     children: [
        //       const DrawerHeader(
        //         decoration: BoxDecoration(color: Colors.blue),
        //         child: Text(
        //           'My Sidebar',
        //           style: TextStyle(color: Colors.white, fontSize: 24),
        //         ),
        //       ),
        //       ListTile(
        //         leading: const Icon(Icons.home),
        //         title: const Text('Home'),
        //         onTap: () {
        //           Navigator.pop(context); // close sidebar
        //         },
        //       ),
        //       ListTile(
        //         leading: const Icon(Icons.settings),
        //         title: const Text('Settings'),
        //         onTap: () {
        //           Navigator.pop(context);
        //         },
        //       ),
        //       ListTile(
        //         leading: const Icon(Icons.logout),
        //         title: const Text('Logout'),
        //         onTap: () {
        //           Navigator.pop(context);
        //         },
        //       ),
        //     ],
        //   ),
        // ),

            body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 36, 7, 156),
                  Color.fromARGB(255, 8, 0, 255),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            width: double.infinity,
            child: TextContainer(
              currentData["question"] as String,
              const Color.fromARGB(255, 0, 255, 255),
              30,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          margin: const EdgeInsets.all(20),
          width: double.infinity,
          child: SingleChildScrollView(child:Column(children: buttons_Data(currentData)),
          )
        ),
        Container(
          margin: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // pushes to bottom
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // left & right
                children: [
                  (i != 0)?ElevatedButton(
                    onPressed: () {
                      if(i==0){
                      }else{
                        i-=1;
                        switchState();
                      }
                    },
                    child: TextContainer("previous", Colors.black, 18),
                  ):ElevatedButton(
                    onPressed: () {},
                    child: TextContainer("previous", Colors.transparent, 18),
                  ),
                  (i != dataSet.length-2)?ElevatedButton(
                    onPressed: () {
                      if(i==dataSet.length){
                      }else{
                        i+=1;
                        switchState();
                      }
                    },
                    child: TextContainer("NEXT", Colors.black, 18),
                  ):ElevatedButton(
                    onPressed: () {},
                    child: TextContainer("NEXT", Colors.transparent, 18),
                  )
          ],
              ),
            ],
          ),
        )

      ],
    )
        )
    )
    );
  }
}

