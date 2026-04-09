import 'package:go_router/go_router.dart';

import '../screens/accounts/account_detail_screen.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell/shell_screen.dart';
import '../screens/transactions/transaction_detail_screen.dart';
import '../screens/transactions/transaction_form_screen.dart';
import '../screens/transactions/transactions_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => AccountDetailScreen(
                accountId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const TransactionFormScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => TransactionDetailScreen(
                txId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => TransactionFormScreen(
                    txId: state.pathParameters['id'],
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatScreen(),
          routes: [
            GoRoute(
              path: ':session_id',
              builder: (context, state) => ChatScreen(
                sessionId: state.pathParameters['session_id'],
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
