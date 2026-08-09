import 'package:flutter/material.dart';

class RegistrationForm extends StatefulWidget {
  final Function(Map<String, String>)? onSubmit;

  const RegistrationForm({Key? key, this.onSubmit}) : super(key: key);

  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  
  String email = '';
  String password = '';
  String fullName = '';
  String username = '';

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.onSubmit != null) {
        widget.onSubmit!({
          'email': email,
          'password': password,
          'fullName': fullName,
          'username': username,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('email_field'),
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              return null;
            },
            onSaved: (value) => email = value!,
          ),
          TextFormField(
            key: const Key('password_field'),
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
            onSaved: (value) => password = value!,
          ),
          TextFormField(
            key: const Key('full_name_field'),
            decoration: const InputDecoration(labelText: 'Full Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Full Name is required';
              }
              return null;
            },
            onSaved: (value) => fullName = value!,
          ),
          TextFormField(
            key: const Key('username_field'),
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Username is required';
              }
              return null;
            },
            onSaved: (value) => username = value!,
          ),
          ElevatedButton(
            key: const Key('register_button'),
            onPressed: _submit,
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}

