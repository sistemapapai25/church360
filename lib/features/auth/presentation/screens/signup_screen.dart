import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_branding.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/app_logo.dart';
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
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCheckingEmail = false;
  bool _foundVisitorData = false;
  bool _viewedLgpdPolicy = false;
  bool _viewedCommitmentTerms = false;
  bool _acceptedLgpd = false;
  bool _acceptedCommitmentTerms = false;

  Timer? _debounceTimer;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _debounceTimer?.cancel();
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
          _nicknameController.text = (visitorData['nickname'] ?? visitorData['apelido'] ?? '') ?? '';
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
    if (!_acceptedLgpd || !_acceptedCommitmentTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leia e aceite LGPD e Termos de Compromisso para concluir o cadastro.'),
          backgroundColor: Colors.orange,
        ),
      );
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
        nickname: _nicknameController.text.trim(),
        lgpdConsent: _acceptedLgpd,
        commitmentTermsAccepted: _acceptedCommitmentTerms,
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

  Future<void> _openLegalDocument({
    required String title,
    required String subtitle,
    required List<String> paragraphs,
    required VoidCallback onReadConfirmed,
  }) async {
    final wasRead = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final paragraph in paragraphs) ...[
                          Text(paragraph),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Fechar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Li e estou ciente'),
            ),
          ],
        );
      },
    );

    if (wasRead == true && mounted) {
      setState(onReadConfirmed);
    }
  }

  Future<void> _readLgpdPolicy() async {
    await _openLegalDocument(
      title: 'Consentimento LGPD',
      subtitle: 'Leia antes de conceder o consentimento.',
      paragraphs: const [
        'Seus dados pessoais serão utilizados exclusivamente para finalidades ministeriais e administrativas da igreja, como identificação, contato e acompanhamento pastoral.',
        'O tratamento dos dados seguirá os princípios da LGPD (Lei 13.709/2018), incluindo necessidade, transparência, segurança e minimização.',
        'Você pode solicitar correção, anonimização, portabilidade, revogação de consentimento e exclusão, conforme hipóteses legais aplicáveis.',
        'Ao conceder o consentimento, o sistema registra data e horário para comprovação e auditoria interna.',
      ],
      onReadConfirmed: () {
        _viewedLgpdPolicy = true;
      },
    );
  }

  Future<void> _readCommitmentTerms() async {
    await _openLegalDocument(
      title: 'Termos de Compromisso',
      subtitle: 'Leia os termos antes de aceitar no cadastro.',
      paragraphs: const [
        'Ao se cadastrar, você confirma que as informações fornecidas são verdadeiras e poderão ser usadas para comunicação oficial da igreja.',
        'Você se compromete a manter seus dados atualizados e a utilizar os recursos do aplicativo de forma ética e respeitosa.',
        'A liderança pastoral pode visualizar o status de aceite dos termos e de consentimento LGPD para fins de conformidade.',
        'O descumprimento das diretrizes pode implicar restrições de acesso conforme regras internas da organização.',
      ],
      onReadConfirmed: () {
        _viewedCommitmentTerms = true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CommunityDesign.radius),
              boxShadow: [CommunityDesign.overlayBaseShadow()],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: const AppLogo(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Título
                  Text(
                    AppBranding.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtítulo
                  Text(
                    AppBranding.organizationName,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: CommunityDesign.metaStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppBranding.signUpPrompt,
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                  const SizedBox(height: 32),

                  // Campo de Email (PRIMEIRO)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    autofillHints: const [AutofillHints.email],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      hintText: 'seu@email.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
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
                  const SizedBox(height: 20),

                  // Campo de Nome
                  TextFormField(
                    controller: _firstNameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Nome *',
                      hintText: 'Seu primeiro nome',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo de Sobrenome
                  TextFormField(
                    controller: _lastNameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.familyName],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Sobrenome *',
                      hintText: 'Seu sobrenome',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu sobrenome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Campo de Apelido
                  TextFormField(
                    controller: _nicknameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.nickname],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Apelido *',
                      hintText: 'Como você é conhecido(a)',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira seu apelido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo de Senha
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                  const SizedBox(height: 20),
                  
                  // Campo de Confirmar Senha
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Senha',
                      hintText: 'Digite a senha novamente',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consentimentos obrigatórios',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Leia os documentos e confirme o aceite para finalizar seu cadastro.',
                          style: CommunityDesign.metaStyle(context),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _readLgpdPolicy,
                          icon: Icon(
                            _viewedLgpdPolicy
                                ? Icons.check_circle
                                : Icons.article_outlined,
                            color: _viewedLgpdPolicy ? Colors.green : null,
                          ),
                          label: Text(
                            _viewedLgpdPolicy
                                ? 'LGPD lida'
                                : 'Ler consentimento LGPD',
                          ),
                        ),
                        CheckboxListTile(
                          value: _acceptedLgpd,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: _viewedLgpdPolicy
                              ? (value) {
                                  setState(() {
                                    _acceptedLgpd = value ?? false;
                                  });
                                }
                              : null,
                          title: const Text('Concordo com o consentimento LGPD'),
                          subtitle: Text(
                            _viewedLgpdPolicy
                                ? 'Consentimento será registrado para auditoria pastoral.'
                                : 'Leia o documento LGPD para habilitar o aceite.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _readCommitmentTerms,
                          icon: Icon(
                            _viewedCommitmentTerms
                                ? Icons.check_circle
                                : Icons.description_outlined,
                            color: _viewedCommitmentTerms ? Colors.green : null,
                          ),
                          label: Text(
                            _viewedCommitmentTerms
                                ? 'Termos lidos'
                                : 'Ler termos de compromisso',
                          ),
                        ),
                        CheckboxListTile(
                          value: _acceptedCommitmentTerms,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: _viewedCommitmentTerms
                              ? (value) {
                                  setState(() {
                                    _acceptedCommitmentTerms = value ?? false;
                                  });
                                }
                              : null,
                          title: const Text('Aceito os termos de compromisso'),
                          subtitle: Text(
                            _viewedCommitmentTerms
                                ? 'Aceite obrigatório para criação da conta.'
                                : 'Leia os termos para habilitar o aceite.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Botão de Cadastro
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5FA5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Criar Conta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Link para Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Já tem uma conta? ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0B5FA5),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
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
