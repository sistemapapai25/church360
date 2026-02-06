import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'financeiro_papai_web_support_stub.dart' if (dart.library.html) 'financeiro_papai_web_support_web.dart'
    as web_support;

/// Tela que embeda o sistema Finanças Papai via iframe (Web) ou WebView (Mobile)
///
/// Esta tela carrega o aplicativo React do Finanças Papai que agora
/// está conectado ao mesmo banco de dados Supabase do Church 360.
class FinanceiroPapaiScreen extends StatefulWidget {
  const FinanceiroPapaiScreen({super.key});

  @override
  State<FinanceiroPapaiScreen> createState() => _FinanceiroPapaiScreenState();
}

class _FinanceiroPapaiScreenState extends State<FinanceiroPapaiScreen> {
  final String _iframeUrl = 'http://localhost:5173';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerIframeView();
    }
  }

  void _registerIframeView() {
    web_support.registerIframeViewFactory(
      viewType: 'financeiro-papai-iframe',
      url: _iframeUrl,
      onLoad: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
        });
      },
      onError: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao carregar o Finanças Papai';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro - Finanças Papai'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Recarregar a página
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              // Força reconstrução do widget
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() {});
                }
              });
            },
            tooltip: 'Recarregar',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () {
              // Abrir em nova aba
              if (kIsWeb) {
                web_support.openInNewTab(_iframeUrl);
              }
            },
            tooltip: 'Abrir em nova aba',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            _buildErrorView()
          else if (kIsWeb)
            _buildWebView()
          else
            _buildMobileNotSupported(),
          if (_isLoading && _errorMessage == null)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando Finanças Papai...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return const HtmlElementView(
      viewType: 'financeiro-papai-iframe',
    );
  }

  Widget _buildMobileNotSupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.phone_android,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Versão Mobile em Desenvolvimento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'O módulo financeiro está disponível apenas na versão web por enquanto.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (kIsWeb) {
                  web_support.openInNewTab(_iframeUrl);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Abrir no Navegador'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Erro desconhecido',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Certifique-se de que o servidor Finanças Papai está rodando em http://localhost:5173',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                if (kIsWeb) {
                  web_support.openInNewTab(_iframeUrl);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir em Nova Aba'),
            ),
          ],
        ),
      ),
    );
  }
}
