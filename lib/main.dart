import 'package:flutter/material.dart';
import 'live_map_page.dart';
import 'login_page.dart'; // Importa el archivo de la página de login

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Google Maps',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage( // Mostrar LoginPage directamente
        loginButtonColor: Color.fromARGB(255, 54, 98, 244),
        createAccountButtonColor: Color.fromRGBO(25, 66, 247, 1), // Color naranja definido por RGB
        textColor: Colors.white,
      ),
    );
  }
}
