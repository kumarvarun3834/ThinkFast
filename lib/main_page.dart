import 'package:flutter/material.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/quesations.dart';
import 'package:thinkfast/start_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/google_sign_in_provider.dart';

class main_page extends StatefulWidget {
  final Function(Widget) onStateChange;

  const main_page({required this.onStateChange, super.key});

  @override
  State<main_page> createState() => _MainPageState();
}

class _MainPageState extends State<main_page> {
  GoogleSignInAccount? _user;
  final GoogleSignInProvider _provider = GoogleSignInProvider();

  @override
  void initState() {
    super.initState();
    _setupGoogleSignIn();
  }

  Future<void> _setupGoogleSignIn() async {
    try {
      // Initialize with serverClientId (mandatory for Android)
      await _provider.initialize(
        serverClientId:
        "775124683303-g0rnar32rjagj6kpn5fq82945rkbtofe.apps.googleusercontent.com",
      );

      // Attempt silent/lightweight login
      GoogleSignInAccount? account =
      await _provider.instance.attemptLightweightAuthentication();

      // Fallback to interactive login if needed
      account ??= await _provider.instance.authenticate();

      // Set signed-in user
      setState(() {
        _user = account;
      });

      // Listen to authentication events
      _provider.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          setState(() => _user = event.user);
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          setState(() => _user = null);
        }
      });
    } catch (e) {
      print("Google Sign-In initialization error: $e");
    }
  }

  void switchState(String id) {
    List<Map<String, Object>> dataSet = [];
    widget.onStateChange(
      Quesations(dataSet, onStateChange: widget.onStateChange),
    );
  }

  final List<Map<String, Object>> dataSet = [
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
          "type": "multiple",
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: TextContainer("THINKFAST", Colors.black, 20)),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                    (_user?.photoUrl != null) ? NetworkImage(_user!.photoUrl!) : null,
                    child: (_user?.photoUrl == null)
                        ? const Icon(Icons.account_circle, size: 60, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _user != null
                        ? "Hi, ${_user!.displayName ?? _user!.email}"
                        : "Hi, Guest",
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            SidebarMenu(
              googleSignIn: _provider.instance,
              user: _user,
              onStateChange: widget.onStateChange,
              refreshParent: () => setState(() {}), // refresh sidebar
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Quesations(dataSet, onStateChange: widget.onStateChange),
                // child: Main_Screen(onPressed: widget.onStateChange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
