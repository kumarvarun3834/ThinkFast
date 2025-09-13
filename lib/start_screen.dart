import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:thinkfast/TextContainer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thinkfast/drawer_data.dart';
import 'package:thinkfast/google_sign_in_provider.dart';
// import 'package:thinkfast/quesations.dart';
import 'package:thinkfast/global.dart' as global;

class Main_Screen extends StatefulWidget {
  // final Function(Widget) onPressed;
  final GoogleSignInAccount? creatorId;
  final bool? visibility;

  const Main_Screen({
    super.key,
    this.creatorId,
    this.visibility=false,
  });

  @override
  State<Main_Screen> createState() => _Main_ScreenState();
}

class _Main_ScreenState extends State<Main_Screen> {
  GoogleSignInAccount? _user;
  final GoogleSignInProvider _provider = GoogleSignInProvider();

  final CollectionReference _db =
  FirebaseFirestore.instance.collection('databases');

  @override
  void initState() {
    super.initState();
    _setupGoogleSignIn();
  }

  Future<void> _setupGoogleSignIn() async {
    try {
      await _provider.initialize(
        serverClientId:
        "775124683303-g0rnar32rjagj6kpn5fq82945rkbtofe.apps.googleusercontent.com",
      );

      GoogleSignInAccount? account =
      await _provider.instance.attemptLightweightAuthentication();

      account ??= await _provider.instance.authenticate();

      setState(() => _user = account);

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

  Stream<List<Map<String, dynamic>>> readDatabases() {
    Query query = _db;

    if (widget.visibility == false) {
      query = query.where("visibility", isEqualTo: "public");
    }else if (widget.creatorId != null) {
      query = query.where('creatorId', isEqualTo: widget.creatorId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  ElevatedButton button_data (Map<String, dynamic> data,String button_name,final String redirect){
    return ElevatedButton(
      onPressed: () {
        global.quizData =
        (data["data"] as List<dynamic>)
            .map((e) => Map<String, Object>.from(e as Map))
            .toList();
        Navigator.pushNamed(context,redirect);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      child: Text(
        button_name,
        style: GoogleFonts.poppins(
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  // final List<Map<String, Object>> quizData =
  // (data["data"] as List<dynamic>)
  //     .map((e) => Map<String, Object>.from(e as Map))
  //     .toList();

  Widget buildQuizCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.all(15),
      elevation: 3,
      color: const Color.fromARGB(255, 255, 225, 255),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.blueAccent,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextContainer(
                      "Title: ${data["title"] ?? "Untitled"}", Colors.white, 26),
                  const SizedBox(height: 5),
                  TextContainer(
                      "Description: ${data["description"] ?? "No description"}",
                      Colors.white70,
                      20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(children: [
              button_data(data,"Start Quiz","/Quiz"),
              if (widget.visibility==true)button_data(data,"updateQuiz","/Quiz")
              ]
          ),
          )],
      ),
    );
  }

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
              refreshParent: () => setState(() {}),
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
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: readDatabases(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No quizzes available.'));
            }

            final dataset = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: dataset.map(buildQuizCard).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
