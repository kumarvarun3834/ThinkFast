import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';

class  Main_Screen extends StatelessWidget {
  final VoidCallback onPressed;
  List<Map<String,Object>> dataset=[
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user2",
      'title': "title2",
      'description': "description2",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    },
    {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // mock ID
      'user': "user1",
      'title': "title1",
      'description': "description1",
      'visibility': 'public',
      'data':  [
        {
          "question": "What are the main building blocks of Flutter UIs?",
          "answer": ["Widgets"],
          "options": [
            "Components",
            "Blocks",
            "Functions",
            "Widgets"
          ]
        },
        {
          "question": "How are Flutter UIs built?",
          "answer": ["By combining widgets in code"],
          "options": [
            "By combining widgets in a visual editor",
            "By defining widgets in config files",
            "By using XCode for iOS and Android Studio for Android",
            "By combining widgets in code"
          ]
        },
        {
          "question": "What's the purpose of a StatefulWidget?",
          "answer": ["Update UI as data changes"],
          "options": [
            "Update data as UI changes",
            "Ignore data changes",
            "Render UI that does not depend on data",
            "Update UI as data changes"
          ]
        },
        {
          "question": "Which widget should you try to use more often: StatelessWidget or StatefulWidget?",
          "answer": ["StatelessWidget"],
          "options": [
            "StatefulWidget",
            "Both are equally good",
            "None of the above",
            "StatelessWidget"
          ]
        },
        {
          "question": "What happens if you change data in a StatelessWidget?",
          "answer": ["The UI is not updated"],
          "options": [
            "The UI is updated",
            "The closest StatefulWidget is updated",
            "Any nested StatefulWidgets are updated",
            "The UI is not updated"
          ]
        },
        {
          "question": "How should you update data inside of StatefulWidgets?",
          "answer": ["By calling setState()"],
          "options": [
            "By calling updateData()",
            "By calling updateUI()",
            "By calling updateState()",
            "By calling setState()"
          ]
        }
      ],
    }

  ];
  Main_Screen({super.key,required this.onPressed});

  List<Widget> quizCards(int size){
    List<Widget> widgets=[];
    for(int y=0;y<size;y++){
    widgets.add(Card(
      margin: EdgeInsets.all(15),
      elevation: 3,
      color: const Color.fromARGB(255, 255, 225, 255),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
        child: Column(
            mainAxisAlignment:MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Card(
        color: Colors.blueAccent,
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              TextContainer(dataset[y]["title"] as String, Colors.black, 30),
          TextContainer("Are you ready ?", Colors.black, 30),]
            )
            )
            ),
            ElevatedButton(onPressed: (){}, child: TextContainer("click $y", Colors.black, 20)
                ,style: ElevatedButton.styleFrom(

                  // padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  backgroundColor: Colors.white12,
                  // foregroundColor: colour,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),)
            ]
        ),
    ));}
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    // return Center(child: TextContainer("works", Colors.black, 50));
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        //   mainAxisSize: MainAxisSize.min,
        children: quizCards(dataset.length)
        );
  }
}
