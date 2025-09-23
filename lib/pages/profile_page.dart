// lib/pages/profile_page.dart
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editing = false;

  final _name = TextEditingController(text: 'Alan Norton');        // e.g., Omkar Nikam
  final _email = TextEditingController(text: 'nortona@rowan.edu');
  final _role = TextEditingController(text: 'Admin');
  final _phone = TextEditingController(text: '+1 (111) 111-1111');
  final _org  = TextEditingController(text: 'CREATEs • Rowan');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _role.dispose();
    _phone.dispose();
    _org.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: cs.primaryContainer,
                child: const Icon(Icons.person, size: 44),
              ),
              if (_editing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: cs.primary,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      onPressed: () {
                        // TODO: pick avatar image
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Avatar update coming soon…')),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Profile',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 16),

        _profileField('Full Name', _name, enabled: _editing, keyboardType: TextInputType.name),
        const SizedBox(height: 12),
        _profileField('Email', _email, enabled: _editing, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _profileField('Role', _role, enabled: _editing),
        const SizedBox(height: 12),
        _profileField('Phone', _phone, enabled: _editing, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _profileField('Organization', _org, enabled: _editing),
        const SizedBox(height: 20),

        // Card(
        //   child: ListTile(
        //     leading: const Icon(Icons.verified_user_outlined),
        //     title: const Text('Created By (default for forms)'),
        //     subtitle: Text(_name.text),
        //     trailing: TextButton(
        //       child: const Text('Use'),
        //       onPressed: () {
        //         // You can lift this up via a provider/state or return it via callback.
        //         ScaffoldMessenger.of(context).showSnackBar(
        //           SnackBar(content: Text('Will use "${_name.text}" as default Created By')),
        //         );
        //       },
        //     ),
        //   ),
        // ),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  setState(() => _editing = !_editing);
                  if (!_editing) {
                    // Save here (API/local prefs)
                    // TODO: persist profile to storage/backend
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile saved')),
                    );
                  }
                },
                icon: Icon(_editing ? Icons.check : Icons.edit),
                label: Text(_editing ? 'Save' : 'Edit'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        Text(
          'Account',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  // TODO: sign out
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Working')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileField(
    String label,
    TextEditingController c, {
    bool enabled = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: c,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: enabled ? const Icon(Icons.edit_outlined) : null,
      ),
    );
  }
}
