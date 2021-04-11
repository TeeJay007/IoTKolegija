import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

import 'package:provider/provider.dart';

String API_URL = '192.168.1.149:1337';

class Door {
  final int id;
  String doorName;
  String doorDescription;
  bool doorEnabled;

  Door(this.id, this.doorName, this.doorDescription, this.doorEnabled);
}

class User extends ChangeNotifier {
  String _jwt = "";
  String username = "";

  bool isLoggedIn() {
    return _jwt != null && _jwt.length > 0;
  }

  Future<bool> logIn(String email, String password) async {
    var resp = await http.post(Uri.http(API_URL, '/auth/local'), body: {
      'identifier': email,
      'password': password
    }); //TODO: change to https
    if (resp.statusCode == 200) {
      var jsonResponse = convert.jsonDecode(resp.body);
      _jwt = jsonResponse['jwt'];
      username = jsonResponse['user']['username'];
      print(_jwt);
      print(username);
      return true;
    }

    return false;
  }

  Future<List<Door>> getSmartDoors() async {
    if (!isLoggedIn()) return null;

    var resp = await http.get(Uri.http(API_URL, '/smart-doors'),
        headers: {'Authorization': 'Bearer ' + _jwt});

    if (resp.statusCode == 200) {
      var jsonResponse = convert.jsonDecode(resp.body);
      List<Door> doors = List<Door>.empty(growable: true);
      for (var door in jsonResponse) {
        doors.add(Door(door['id'], door['doorName'], door['doorDescription'],
            door['doorEnabled']));
      }
      return doors;
    }

    return null;
  }

  Future<bool> changeDoorState(int doorId, bool doorState) async {
    if (!isLoggedIn()) return false;

    var resp = await http.put(Uri.http(API_URL, "/smart-doors/$doorId"),
        headers: {'Authorization': 'Bearer ' + _jwt},
        body: {'doorEnabled': "$doorState"});
    if (resp.statusCode == 200) {
      //var jsonResponse = convert.jsonDecode(resp.body);
      return true;
    }

    return false;
  }

  Future<bool> logOut() async {}
}

void main() {
  runApp(ChangeNotifierProvider(
    create: (context) => User(),
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(title: 'Prisijungimas'),
        '/smart-doors': (context) =>
            SmartDoorPage(title: 'Išmaniųjų durų valdymas')
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _email = "";
  String _password = "";

  bool _isLoading = false;

  void _handleLogin() async {
    if (_email.isEmpty || _password.isEmpty) return; //TODO: Handle empty fields
    setState(() {
      _isLoading = true;
    });

    Provider.of<User>(context, listen: false)
        .logIn(_email, _password)
        .then((value) {
      if (value) {
        Navigator.pushReplacementNamed(context, '/smart-doors');
      } else {
        //TODO: handleError
      }
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: _isLoading
              ? CircularProgressIndicator()
              : Padding(
                  padding: EdgeInsets.only(left: 16, right: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: TextField(
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            border: UnderlineInputBorder(),
                            hintText: 'El. paštas',
                          ),
                          onChanged: (value) {
                            _email = value;
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: TextField(
                          obscureText: true,
                          decoration: InputDecoration(
                            border: UnderlineInputBorder(),
                            hintText: 'Slaptažodis',
                          ),
                          onChanged: (value) {
                            _password = value;
                          },
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _handleLogin,
                        child: Text("Prisijungti"),
                      )
                    ],
                  ),
                ),
        ));
  }
}

class SmartDoorPage extends StatefulWidget {
  SmartDoorPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _SmartDoorPageState createState() => _SmartDoorPageState();
}

class _SmartDoorPageState extends State<SmartDoorPage> {
  List<Door> _doors;
  bool _loading = false;

  Future<void> _refreshDoors() async {
    setState(() {
      _loading = true;
    });

    await Provider.of<User>(context, listen: false)
        .getSmartDoors()
        .then((doors) {
      if (doors == null) return;
      setState(() {
        print('Refreshed doors');
        _doors = doors;
        _loading = false;
      });
    });
  }

  void _changeDoorState(int id, bool state) {
    setState(() {
      _loading = true;
    });

    Provider.of<User>(context, listen: false)
        .changeDoorState(id, state)
        .then((value) {
      if (value) {
        setState(() {
          _doors.where((d) => d.id == id).first.doorEnabled = state;
        });
      }

      setState(() {
        _loading = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshDoors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _doors == null
          ? Center(
              child: Text('Nėra išmaniųjų durų.'),
            )
          : _loading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  child: ListView(
                    children: _doors
                        .map((door) => ListTile(
                              leading: Icon(Icons.vpn_key),
                              title: Text(door.doorName),
                              subtitle: Text(door.doorDescription),
                              trailing: Switch(
                                value: door.doorEnabled,
                                onChanged: (state) {
                                  _changeDoorState(door.id, state);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                  onRefresh: _refreshDoors),
    );
  }
}
