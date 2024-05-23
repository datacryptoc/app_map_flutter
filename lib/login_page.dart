import 'package:flutter/material.dart';
import 'live_map_page.dart';

class LoginPage extends StatefulWidget {
  final Color loginButtonColor;
  final Color createAccountButtonColor;
  final Color textColor;

  const LoginPage({
    super.key,
    this.loginButtonColor = Colors.blue,
    this.createAccountButtonColor = Colors.green,
    this.textColor = Colors.white,
  });

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  void toggleFormType() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Crear Cuenta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su correo electrónico';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su contraseña';
                  }
                  return null;
                },
              ),
              if (!isLogin)
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirmar Contraseña'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirme su contraseña';
                    } else if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Aquí puedes añadir la lógica de autenticación
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LiveMapPage()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLogin ? widget.loginButtonColor : widget.createAccountButtonColor,
                ),
                child: Text(
                  isLogin ? 'Login' : 'Crear Cuenta',
                  style: TextStyle(color: widget.textColor),
                ),
              ),
              TextButton(
                onPressed: toggleFormType,
                child: Text(
                  isLogin ? 'Crear una cuenta' : 'Ya tengo una cuenta',
                  style: TextStyle(color: widget.createAccountButtonColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
