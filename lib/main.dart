import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_branding.dart';
import 'core/constants/supabase_constants.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_logo.dart';
import 'features/support_chat/domain/models/support_agent.dart';
import 'features/support_chat/presentation/providers/agents_providers.dart';
import 'features/support_chat/presentation/widgets/support_chat_container.dart';
import 'features/support_chat/presentation/widgets/universal_support_chat.dart';

void main() {
  runZonedGuarded(
    () {
      // Mantem o binding e o runApp na mesma zone para evitar "Zone mismatch"
      // (muito comum no Flutter Web quando ensureInitialized fica fora do runZonedGuarded).
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.empty,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught platform error during startup: $error');
        debugPrintStack(stackTrace: stack);
        return false;
      };

      runApp(
        const ProviderScope(
          child: AppBootstrap(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught zone error during startup: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeApp();
  }

  Future<void> _initializeApp() async {
    await initializeDateFormatting(
      'pt_BR',
      null,
    ).timeout(const Duration(seconds: 10));
    await SupabaseConstants.loadPersistedTenantId().timeout(
      const Duration(seconds: 5),
    );

    try {
      await Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        anonKey: SupabaseConstants.supabaseAnonKey,
        headers: SupabaseConstants.tenantHeaders,
      ).timeout(const Duration(seconds: 12));
    } catch (error) {
      final message = error.toString().toLowerCase();
      final alreadyInitialized = message.contains('already initialized') ||
          message.contains('already been initialized');
      if (!alreadyInitialized) rethrow;
    }

    final client = Supabase.instance.client;
    SupabaseConstants.applyTenantHeadersToClient(client);

    final user = client.auth.currentUser ?? client.auth.currentSession?.user;
    if (user != null) {
      unawaited(
        SupabaseConstants.syncTenantFromServer(client)
            .timeout(const Duration(seconds: 8))
            .catchError((error, stack) {
          debugPrint('Tenant sync failed during bootstrap: $error');
          debugPrintStack(stackTrace: stack is StackTrace ? stack : null);
        }),
      );
    }
  }

  void _retry() {
    setState(() {
      _initialization = _initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapMaterialApp(
            child: _BootstrapLoadingScreen(),
          );
        }

        if (snapshot.hasError) {
          return _BootstrapMaterialApp(
            child: _BootstrapErrorScreen(
              error: snapshot.error,
              onRetry: _retry,
            ),
          );
        }

        return const Church360App();
      },
    );
  }
}

class _BootstrapMaterialApp extends StatelessWidget {
  final Widget child;

  const _BootstrapMaterialApp({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBranding.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      home: child,
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 120,
                height: 120,
                child: AppLogo(),
              ),
              const SizedBox(height: 24),
              Text(
                AppBranding.appName,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicializando o aplicativo...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 36),
              CircularProgressIndicator(color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _BootstrapErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final message = error?.toString().trim();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: cs.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Falha ao iniciar o app',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  message == null || message.isEmpty
                      ? 'Ocorreu um erro durante a inicialização.'
                      : message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Church360App extends StatelessWidget {
  const Church360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppBranding.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        return Consumer(
          builder: (context, ref, _) {
            final agentsAsync = ref.watch(visibleAgentsForCurrentUserProvider);

            return agentsAsync.when(
              data: (agents) {
                final overlayListenable = Listenable.merge([
                  appRouter.routeInformationProvider,
                  overlayRefresh,
                ]);
                return ListenableBuilder(
                  listenable: overlayListenable,
                  builder: (context, _) {
                    final currentUri = appRouter.routeInformationProvider.value.uri;

                    Uri effectiveUri(Uri uri) {
                      final frag = uri.fragment.trim();
                      if (frag.isEmpty) return uri;
                      if (uri.path != '/' && uri.path.isNotEmpty) return uri;
                      final normalized = frag.startsWith('/') ? frag : '/$frag';
                      try {
                        return Uri.parse(normalized);
                      } catch (_) {
                        return uri;
                      }
                    }

                    final effectiveCurrentUri = effectiveUri(currentUri);

                    bool allowFloatingOnCurrentRoute(Uri uri) {
                      final p = uri.path;
                      if (p == '/login') return false;
                      if (p == '/signup') return false;
                      if (p == '/splash') return false;
                      return true;
                    }

                    bool matchesLocation(String configured, Uri current) {
                      String raw = configured.trim();
                      if (raw.isEmpty) return false;

                      if (raw.startsWith('/#/')) raw = raw.substring(2);
                      if (raw.startsWith('#/')) raw = raw.substring(1);
                      if (raw.startsWith('#')) raw = raw.substring(1);

                      Uri? cfgUri;
                      try {
                        final normalized = raw.startsWith('/') ? raw : '/$raw';
                        cfgUri = Uri.parse(normalized);
                      } catch (_) {
                        return false;
                      }

                      final effectiveCurrent = effectiveUri(current);

                      if (cfgUri.pathSegments.any((s) => s.startsWith(':'))) {
                        final cfgSegs = cfgUri.pathSegments;
                        final curSegs = effectiveCurrent.pathSegments;
                        if (cfgSegs.length != curSegs.length) return false;
                        for (var i = 0; i < cfgSegs.length; i++) {
                          final s = cfgSegs[i];
                          if (s.startsWith(':')) continue;
                          if (s != curSegs[i]) return false;
                        }
                      } else {
                        if (cfgUri.path != effectiveCurrent.path) {
                          final cfgPath = cfgUri.path.endsWith('/') ? cfgUri.path : '${cfgUri.path}/';
                          if (!effectiveCurrent.path.startsWith(cfgPath)) return false;
                        }
                      }

                      if (cfgUri.queryParameters.isNotEmpty) {
                        for (final entry in cfgUri.queryParameters.entries) {
                          if (effectiveCurrent.queryParameters[entry.key] != entry.value) return false;
                        }
                      }

                      return true;
                    }

                    Uri? parseConfiguredUri(String configured) {
                      String raw = configured.trim();
                      if (raw.isEmpty) return null;
                      if (raw.startsWith('/#/')) raw = raw.substring(2);
                      if (raw.startsWith('#/')) raw = raw.substring(1);
                      if (raw.startsWith('#')) raw = raw.substring(1);
                      try {
                        final normalized = raw.startsWith('/') ? raw : '/$raw';
                        return Uri.parse(normalized);
                      } catch (_) {
                        return null;
                      }
                    }

                    ResolvedAgent? selected;
                    var selectedScore = -1;
                    for (final a in agents) {
                      if (!a.showFloatingButton) continue;
                      final route = (a.floatingRoute ?? '').trim();
                      final normalized = route.isEmpty ? '/home' : route;
                      if (!matchesLocation(normalized, effectiveCurrentUri)) continue;
                      final cfgUri = parseConfiguredUri(normalized);
                      final pathScore = (cfgUri?.pathSegments.length ?? 0) * 10;
                      final queryScore = (cfgUri?.queryParameters.length ?? 0);
                      final score = pathScore + queryScore;
                      if (score > selectedScore) {
                        selected = a;
                        selectedScore = score;
                      }
                    }

                    ResolvedAgent? findDefaultAgent() {
                      for (final a in agents) {
                        if (!a.showFloatingButton) continue;
                        if (a.key.toLowerCase() == 'default') return a;
                      }
                      for (final a in agents) {
                        if (a.showFloatingButton) return a;
                      }
                      return null;
                    }

                    if (selected == null && effectiveCurrentUri.path == '/home') {
                      for (final a in agents) {
                        if (a.key.toLowerCase() == 'default') {
                          selected = a;
                          break;
                        }
                      }
                    }

                    if (selected == null && allowFloatingOnCurrentRoute(effectiveCurrentUri)) {
                      selected = findDefaultAgent();
                    }

                    if (selected == null) return appChild;
                    final selectedAgent = selected;

                    final safeBottom = MediaQuery.of(context).padding.bottom;
                    final isHomeShell = effectiveCurrentUri.path == '/home';
                    const double navBarHeight = 80.0;
                    const double navBarGap = 12.0;
                    final bottomOffset = isHomeShell
                        ? (16.0 + navBarHeight + navBarGap)
                        : (16.0 + safeBottom);

                    final chat = SupportChatContainer(
                      title: 'Fale Conosco',
                      bottomOffset: bottomOffset,
                      agentKey: selectedAgent.key,
                      accentColor: selectedAgent.themeColor,
                      childBuilder: (onAgentChanged, agentKey, accentColor) =>
                          UniversalSupportChat(
                        agentKey: agentKey,
                        accentColor: accentColor,
                        onAgentChanged: onAgentChanged,
                      ),
                    );

                    return _AppOverlayRoot(
                      appChild: appChild,
                      overlayChild: chat,
                    );
                  },
                );
              },
              loading: () => appChild,
              error: (_, __) => appChild,
            );
          },
        );
      },

      // Localizações
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
    );
  }
}

class _AppOverlayRoot extends StatefulWidget {
  final Widget appChild;
  final Widget overlayChild;

  const _AppOverlayRoot({
    required this.appChild,
    required this.overlayChild,
  });

  @override
  State<_AppOverlayRoot> createState() => _AppOverlayRootState();
}

class _AppOverlayRootState extends State<_AppOverlayRoot> {
  late final OverlayEntry _appEntry;
  late final OverlayEntry _overlayEntry;

  @override
  void initState() {
    super.initState();
    _appEntry = OverlayEntry(builder: (context) => widget.appChild);
    _overlayEntry = OverlayEntry(builder: (context) => widget.overlayChild);
  }

  @override
  void didUpdateWidget(covariant _AppOverlayRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _appEntry.markNeedsBuild();
    _overlayEntry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        _appEntry,
        _overlayEntry,
      ],
    );
  }
}
