import 'package:flutter/material.dart';
import "../widgets/custom_widgets.dart";
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'registration_screen.dart';
import 'login_screen.dart';

class AccountSelectionScreen extends StatelessWidget {
  const AccountSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Choose Account',
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final accountHistory = auth.accountHistory;

          return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Previous Accounts Section
                  if (accountHistory.isNotEmpty) ...[
                    Text(
                      'Continue as',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...accountHistory
                        .map((account) => _buildAccountTile(context, account)),
                    const SizedBox(height: 24),
                  ],

                  // Create Account Section
                  Text(
                    'Get started',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildCreateAccountTile(context),

                  // Login Option
                  const SizedBox(height: 16),
                  _buildLoginTile(context),
                ],
              ),
            );
          },
        ),
    );
  }

  Widget _buildAccountTile(BuildContext context, UserAccount account) {
    return Builder(
      builder: (bCtx) {
        final cs = Theme.of(bCtx).colorScheme;
        final isDark = Theme.of(bCtx).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                account.name.isNotEmpty ? account.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(
              account.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(account.email),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (value == 'remove') {
                  await auth.removeAccount(account.email);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Account removed'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      const Text('Remove Account'),
                    ],
                  ),
                ),
              ],
              icon: Icon(
                Icons.more_vert,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LoginScreen(initialEmail: account.email),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCreateAccountTile(BuildContext context) {
    return Builder(
      builder: (bCtx) {
        final cs = Theme.of(bCtx).colorScheme;
        final isDark = Theme.of(bCtx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: CircleAvatar(
              backgroundColor: cs.secondaryContainer,
              child: Icon(
                Icons.person_add,
                color: cs.onSecondaryContainer,
              ),
            ),
            title: const Text(
              'Create Account',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Sign up for a new account'),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RegistrationScreen()),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoginTile(BuildContext context) {
    return Builder(
      builder: (bCtx) {
        final cs = Theme.of(bCtx).colorScheme;
        final isDark = Theme.of(bCtx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: isDark ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(
                Icons.login,
                color: cs.onPrimaryContainer,
              ),
            ),
            title: const Text(
              'Login to Account',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Sign in to your existing account'),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        );
      },
    );
  }
}
