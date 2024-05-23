import 'package:flutter/material.dart';
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
        loginButtonColor: Color.fromARGB(255, 43, 116, 253),
        createAccountButtonColor: Color.fromARGB(255, 43, 116, 253), // Color naranja definido por RGB
        textColor: Color.fromARGB(255, 0, 0, 0),
      ),
    );
  }
}
