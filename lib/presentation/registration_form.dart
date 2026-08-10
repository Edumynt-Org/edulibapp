import 'package:flutter/material.dart';

class RegistrationForm extends StatefulWidget {
  final Function(Map<String, String>)? onSubmit;

  const RegistrationForm({super.key, this.onSubmit});

  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  
  String email = '';
  String password = '';
  String firstName = '';
  String lastName = '';

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.onSubmit != null) {
        widget.onSubmit!({
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('first_name_field'),
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    return null;
                  },
                  onSaved: (value) => firstName = value!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  key: const Key('last_name_field'),
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    return null;
                  },
                  onSaved: (value) => lastName = value!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('email_field'),
            decoration: InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              return null;
            },
            onSaved: (value) => email = value!,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('password_field'),
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              return null;
            },
            onSaved: (value) => password = value!,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('register_button'),
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account?', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text('Skip for now', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

