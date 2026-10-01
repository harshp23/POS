import 'package:flutter/material.dart';

import '../data/api/api_client.dart';
import 'dashboard/dashboard_widgets.dart' show friendlyErrorText;
import 'vinii_theme.dart';

/// Shown right after sign-in when an admin reset the password (or ticked
/// "Force password change"): the staff member picks their own password
/// before using the app. Returns true once changed, false to sign out.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, required this.api});
  final ProviyaaApiClient api;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = _next.text;
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter the password you signed in with.');
      return;
    }
    if (next.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (next != _confirm.text) {
      setState(() => _error = 'The new passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.changePassword(_current.text, next);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // The server's message says what to fix; anything else gets a plain
      // sentence instead of program text.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyErrorText(e,
              fallback: 'Could not change the password. Please try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration field(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Set a new password'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your password was reset by your manager. Choose your own password to continue.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                  key: const Key('pw-current'),
                  controller: _current,
                  obscureText: true,
                  decoration: field('Current (temporary) password')),
              const SizedBox(height: 12),
              TextField(
                  key: const Key('pw-new'),
                  controller: _next,
                  obscureText: true,
                  decoration: field('New password')),
              const SizedBox(height: 12),
              TextField(
                  key: const Key('pw-confirm'),
                  controller: _confirm,
                  obscureText: true,
                  decoration: field('Confirm new password'),
                  onSubmitted: (_) => _save()),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Colors.red[700], fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Sign out'),
          ),
          FilledButton(
            key: const Key('pw-save'),
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                backgroundColor: ViniiColors.brandGreen,
                foregroundColor: Colors.black),
            child: Text(_saving ? 'Saving…' : 'Change password'),
          ),
        ],
      ),
    );
  }
}
