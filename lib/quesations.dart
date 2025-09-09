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

  // Sample dynamic data with numbers instead of names
  final List<Map<String, dynamic>> drawerItems = [
    {"number": 1, "color": Colors.blue},
    {"number": 2, "color": Colors.green},
    { "number": 3, "color": Colors.red},
    { "number": 4, "color": Colors.orange},
    { "number": 5, "color": Colors.purple},
  ];

  // ListTile tiles(int index){
  //   return ListTile(
  //     // leading: const Icon(Icons.),
  //     title: Text("$index"),
  //     onTap: () {
  //       i=index;
  //     },
  //   );
  // }

  // List<ListTile> menu_opt(){
  //   List<ListTile> menu_opt =[];
  //   for(int y=0;y<=dataSet.length-1;y++){
  //     menu_opt.add(tiles(y));
  //   }
  //   return menu_opt;
  // }

  List<Widget> menu_opt() {
    final List<Map<String, dynamic>> drawerItems = [
      {"icon": Icons.looks_one, "number": 1, "color": Colors.red},
      {"icon": Icons.looks_two, "number": 2, "color": Colors.green},
      {"icon": Icons.looks_3, "number": 3, "color": Colors.blue},
      {"icon": Icons.looks_4, "number": 4, "color": Colors.orange},
      {"icon": Icons.looks_5, "number": 4, "color": Colors.orange},
      {"icon": Icons.looks_6, "number": 4, "color": Colors.orange},
    ];

    return [
      for (int j = 0; j < drawerItems.length; j++)
        GestureDetector(
          onTap: () {
            i=j;
            switchState();
          },
          child: Container(
            width: 70,
            height: 70,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: drawerItems[j]["color"],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(drawerItems[j]["icon"], color: Colors.white, size: 30),
                const SizedBox(height: 4),
                Text(
                  "${drawerItems[j]["number"]}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
        title: 'Custom AppBar',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: Scaffold(
            appBar: AppBar(
              titleSpacing: 0, // so title sits right after menu button
              title: const Text("Quiz name"),
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
            drawer: Drawer(
              child: Column(
                children: [
                  const DrawerHeader(
                    decoration: BoxDecoration(color: Colors.blue),
                    child: Text(
                      'Questions',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 10, // horizontal space between items
                        runSpacing: 10, // vertical space between rows
                        children: menu_opt(), // returns list of widgets
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
      mainAxisAlignment: MainAxisAlignment.start,
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
          child: SingleChildScrollView(child:Column(children: buttons_Data(currentData)),)
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

