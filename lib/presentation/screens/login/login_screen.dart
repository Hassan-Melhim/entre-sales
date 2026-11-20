import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../staff_accounts.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/staff_avatar.dart';

/// "Who's working?": one tile per staff member; tapping one asks for their
/// password. Other logins (e.g. the developer's) use "Another account".
/// Accounts are created in Supabase; there is no sign-up here.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.loginMax),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('entre',
                      style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Who\'s working today?',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.l,
                    runSpacing: AppSpacing.l,
                    children: [
                      for (var i = 0; i < staffAccounts.length; i++) _StaffTile(staffAccounts[i], colorIndex: i),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextButton(
                    onPressed: () => _askPassword(context, null),
                    child: const Text('Another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final StaffAccount staff;
  final int colorIndex;
  const _StaffTile(this.staff, {required this.colorIndex});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.staffTileWidth,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _askPassword(context, staff, colorIndex: colorIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.l, horizontal: AppSpacing.m),
            child: Column(
              children: [
                StaffAvatar(staff, colorIndex: colorIndex),
                const SizedBox(height: AppSpacing.m),
                Text(staff.name, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for [staff]'s password (or for an email and password when null)
/// and signs in. The app opens by itself once the sign-in is confirmed.
Future<void> _askPassword(BuildContext context, StaffAccount? staff, {int colorIndex = 0}) =>
    showDialog<void>(context: context, builder: (_) => _PasswordDialog(staff, colorIndex: colorIndex));

class _PasswordDialog extends ConsumerStatefulWidget {
  final StaffAccount? staff;
  final int colorIndex;
  const _PasswordDialog(this.staff, {required this.colorIndex});

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: widget.staff?.email ?? _email.text, password: _password.text);
      TextInput.finishAutofillContext();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final theme = Theme.of(context);
    return AlertDialog(
      content: SizedBox(
        width: context.dialogWidth(AppSizes.dialogSmall),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: StaffAvatar(staff, colorIndex: widget.colorIndex, size: AppSizes.avatarMedium)),
                const SizedBox(height: AppSpacing.m),
                Text(staff == null ? 'Sign in' : 'Hi ${staff.name}',
                    textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.l),
                if (staff == null) ...[
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  autofocus: staff != null,
                  obscureText: !_showPassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy
              ? const SizedBox.square(dimension: AppSizes.iconSmall, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sign in'),
        ),
      ],
    );
  }
}
