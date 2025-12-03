import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

/// Tela de Cadastro
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCheckingEmail = false;
  bool _foundVisitorData = false;

  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Buscar dados de visitante quando o email é alterado (com debounce)
  void _onEmailChanged(String email) {
    debugPrint('🔍 _onEmailChanged chamado com email: $email');

    // Cancelar timer anterior
    _debounceTimer?.cancel();

    // Resetar estado se o email estiver vazio ou inválido
    if (email.isEmpty || !email.contains('@')) {
      debugPrint('❌ Email vazio ou sem @, resetando estado');
      setState(() {
        _foundVisitorData = false;
      });
      return;
    }

    debugPrint('⏱️ Iniciando timer de 1 segundo para buscar dados...');
    // Criar novo timer para esperar 1 segundo após o usuário parar de digitar
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      debugPrint('⏰ Timer disparado! Chamando _checkEmailForVisitorData...');
      _checkEmailForVisitorData(email);
    });
  }

  /// Buscar dados de visitante quando o email é alterado
  Future<void> _checkEmailForVisitorData(String email) async {
    debugPrint('🚀 _checkEmailForVisitorData iniciado para: $email');

    setState(() {
      _isCheckingEmail = true;
      _foundVisitorData = false;
    });

    try {
      debugPrint('📡 Buscando dados no Supabase...');
      final authRepo = ref.read(authRepositoryProvider);
      final visitorData = await authRepo.getVisitorDataByEmail(email.trim());

      debugPrint('📦 Dados recebidos: $visitorData');

      if (visitorData != null && mounted) {
        debugPrint('✅ Visitante encontrado! Preenchendo campos...');
        debugPrint('   - first_name: ${visitorData['first_name']}');
        debugPrint('   - last_name: ${visitorData['last_name']}');

        // Preencher os campos automaticamente
        setState(() {
          _firstNameController.text = visitorData['first_name'] ?? '';
          _lastNameController.text = visitorData['last_name'] ?? '';
          _foundVisitorData = true;
        });

        debugPrint('✅ Campos preenchidos com sucesso!');

        // Mostrar mensagem de sucesso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dados encontrados! Nome e sobrenome preenchidos automaticamente.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint('❌ Nenhum visitante encontrado com este email');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERRO ao buscar dados do visitante: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
        });
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      
      await authRepo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (mounted) {
        // Cadastro bem-sucedido
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Redireciona para home
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        String message = 'Ocorreu um erro ao fazer cadastro.';
        if (e is AuthApiException &&
            e.message.toLowerCase().contains('already registered')) {
          message = 'Este e-mail já está cadastrado. Faça login ou recupere sua senha.';
        } else if (e is AuthException) {
          message = e.message;
        } else {
          message = e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Fazer Login',
              onPressed: () => context.pop(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Ícone
                  Icon(
                    Icons.person_add,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  
                  // Título
                  Text(
                    'Criar Conta',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtítulo
                  Text(
                    'Comece digitando seu email',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Campo de Email (PRIMEIRO)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      hintText: 'seu@email.com',
                      prefixIcon: const Icon(Icons.email),
                      suffixIcon: _isCheckingEmail
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _foundVisitorData
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                      helperText: _foundVisitorData
                          ? '✅ Visitante encontrado! Dados preenchidos automaticamente.'
                          : 'Se você já é visitante, seus dados serão preenchidos automaticamente',
                      helperMaxLines: 2,
                    ),
                    onChanged: _onEmailChanged,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu email';
                      }
                      if (!value.contains('@')) {
                        return 'Por favor, insira um email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo de Nome
                  TextFormField(
                    controller: _firstNameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome *',
                      hintText: 'Seu primeiro nome',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo de Sobrenome
                  TextFormField(
                    controller: _lastNameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Sobrenome *',
                      hintText: 'Seu sobrenome',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu sobrenome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de Senha
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira uma senha';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter no mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de Confirmar Senha
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Senha',
                      hintText: 'Digite a senha novamente',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, confirme sua senha';
                      }
                      if (value != _passwordController.text) {
                        return 'As senhas não coincidem';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Botão de Cadastro
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Criar Conta'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Link para Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Já tem uma conta? '),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Fazer Login'),
                      ),
                    ],
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
