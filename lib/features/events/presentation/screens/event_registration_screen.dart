import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../domain/models/event.dart';
import '../providers/events_provider.dart';
import '../utils/event_full_error.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Tela de inscrição em evento (pública para membros)
class EventRegistrationScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventRegistrationScreen({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends ConsumerState<EventRegistrationScreen> {
  /// VIS-04: copy PT-BR das recusas que `register_event_guest` (migration
  /// `20260826000500`) emite por `RAISE EXCEPTION`. O repositório não traduz
  /// código de erro — por convenção do projeto a copy é da camada de tela —,
  /// então o mapeamento mora aqui e nenhum literal cru chega ao usuário.
  static const Map<String, String> _copyDeRecusaDeConvidado = {
    'EVENT_RESTRICTED':
        'Este evento é restrito. A inscrição sem login não está disponível; entre com sua conta para verificar se você pode participar.',
    'EVENT_NOT_PUBLISHED':
        'As inscrições para este evento ainda não foram abertas.',
    'EVENT_REGISTRATION_DISABLED':
        'As inscrições para este evento não estão habilitadas.',
    'EVENT_ALREADY_FINISHED': 'Este evento já foi finalizado.',
    'EVENT_ALREADY_STARTED':
        'Este evento já começou e não aceita novas inscrições.',
  };

  /// Código de recusa por audiência emitido por `register_member_in_event`
  /// (Plano 07).
  static const String _codigoNaoElegivel = 'NOT_ELIGIBLE';

  /// Copy única da recusa por audiência. Usada nos DOIS pontos — pré-checagem
  /// de UX e `catch` da RPC — porque as duas mensagens não podem divergir.
  static const String _copyNaoElegivel =
      'Você não pertence aos grupos, ministérios ou cargos autorizados a se inscrever neste evento.';

  /// Detecta um `RAISE EXCEPTION` do servidor pelo literal do código. Varre
  /// código, mensagem, detalhes e hint do `PostgrestException` pelo mesmo
  /// motivo de `isEventFullError`: o PostgREST acomoda o literal em campos
  /// diferentes conforme a versão.
  bool _recusaDoServidor(Object error, String codigo) {
    if (error is PostgrestException) {
      final haystack =
          '${error.code ?? ''} ${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
      return haystack.contains(codigo);
    }
    return error.toString().contains(codigo);
  }

  bool _isRegistering = false;
  EventTicket? _generatedTicket;
  bool _isGuestRegistering = false;
  final _guestNameController = TextEditingController();
  final _guestEmailController = TextEditingController();
  final _guestPhoneController = TextEditingController();

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestEmailController.dispose();
    _guestPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Evento não encontrado')),
            body: const Center(child: Text('Evento não encontrado')),
          );
        }

        if (!event.requiresRegistration) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inscrição no Evento')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'As inscrições para este evento não estão habilitadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }

        if (event.status != 'published' || event.isPast) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inscrição no Evento')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  event.isPast
                      ? 'Este evento já foi finalizado.'
                      : 'As inscrições para este evento não estão ativas.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }

        // Se já gerou o ingresso nesta sessão, mostra a tela de sucesso
        if (_generatedTicket != null) {
          return _buildTicketScreen(event, _generatedTicket!);
        }

        // Senão, mostra a tela de inscrição
        return currentMemberAsync.when(
          data: (member) {
            if (member == null) {
              return _buildGuestRegistrationScreen(event);
            }

            // Sai e volta na tela: sem isto, sempre reaparece "inscrever-se
            // gratuitamente" mesmo pra quem já está inscrito, porque
            // _generatedTicket é só estado local desta sessão de tela.
            final registrationsAsync = ref.watch(eventRegistrationsProvider(event.id));
            return registrationsAsync.when(
              data: (registrations) {
                EventRegistration? existing;
                for (final r in registrations) {
                  if (r.memberId == member.id) {
                    existing = r;
                    break;
                  }
                }
                if (existing != null) {
                  return _buildTicketScreen(
                    event,
                    EventTicket(
                      id: existing.id,
                      eventId: event.id,
                      memberId: member.id,
                      qrCode: existing.qrCode ?? 'EVENT_TICKET:${event.id}:${member.id}',
                      status: 'paid',
                      paidAmount: event.isFree ? 0 : event.price,
                      createdAt: existing.registeredAt,
                      paidAt: existing.registeredAt,
                      eventName: event.name,
                    ),
                  );
                }
                return _buildRegistrationScreen(event, member);
              },
              // Falha na leitura não deve travar quem ainda não se inscreveu.
              loading: () => _buildRegistrationScreen(event, member),
              error: (error, stack) => _buildRegistrationScreen(event, member),
            );
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Carregando...')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          // Nenhum `$error` cru na tela: mensagem crua de PostgREST expõe
          // estrutura interna (T-07-03).
          error: (error, stack) => Scaffold(
            appBar: AppBar(title: const Text('Erro')),
            body: Center(
              child: Text(
                AppErrorHandler.userMessage(error, feature: 'events'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Text(
            AppErrorHandler.userMessage(error, feature: 'events'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildGuestRegistrationScreen(Event event) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(title: const Text('Inscrição no Evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inscreva-se sem precisar de conta',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Você pode concluir a inscrição agora. Depois, se quiser acompanhar novidades e outros convites, crie sua conta no app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guestNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome completo *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _guestEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'E-mail *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _guestPhoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Telefone (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isGuestRegistering
                  ? null
                  : () => _registerGuestInEvent(event),
              icon: _isGuestRegistering
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isGuestRegistering ? 'Enviando...' : 'Concluir inscrição'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Já tenho conta'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final email = Uri.encodeComponent(
                        _guestEmailController.text.trim(),
                      );
                      context.push('/signup?email=$email');
                    },
                    child: const Text('Criar conta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerGuestInEvent(Event event) async {
    final name = _guestNameController.text.trim();
    final email = _guestEmailController.text.trim();
    final phone = _guestPhoneController.text.trim();
    if (name.isEmpty || email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um nome e e-mail válidos para concluir a inscrição.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGuestRegistering = true);
    try {
      await ref.read(eventsRepositoryProvider).registerGuest(
            eventId: event.id,
            guestName: name,
            guestEmail: email,
            guestPhone: phone.isEmpty ? null : phone,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inscrição registrada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      // Após registrar, incentivar criação de conta no app (email pré-preenchido)
      final uriEmail = Uri.encodeComponent(email);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tudo certo!'),
          content: const Text(
            'Sua inscrição foi registrada. Para receber novidades e acessar outros recursos, você pode criar sua conta no app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push('/signup?email=$uriEmail');
              },
              child: const Text('Criar conta'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Mesmo contrato do caminho de membro: o visitante também recebe a copy
      // PT-BR de evento lotado, nunca a mensagem crua do PostgREST (T-07-03).
      if (isEventFullError(e)) {
        AppErrorHandler.log(e, feature: 'events');
        ref.invalidate(eventRegistrationsProvider(event.id));
        ref.invalidate(eventByIdProvider(event.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(eventFullMessage(event.maxCapacity))),
        );
        return;
      }

      // VIS-04: recusas nomeadas do servidor viram copy PT-BR. Nenhum
      // tratamento anterior foi removido — `EVENT_FULL` acima continua
      // vindo primeiro, e o que não estiver no mapa segue pelo handler.
      for (final recusa in _copyDeRecusaDeConvidado.entries) {
        if (_recusaDoServidor(e, recusa.key)) {
          AppErrorHandler.log(e, feature: 'events');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(recusa.value)));
          return;
        }
      }

      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'events',
        fallbackMessage:
            'Não foi possível concluir a inscrição. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _isGuestRegistering = false);
    }
  }

  Widget _buildRegistrationScreen(Event event, dynamic member) {
    final isFree = event.isFree || event.price == null || event.price == 0;
    final price = event.price ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscrição no Evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem do evento
            if (event.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  event.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.event, size: 64),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Nome do evento
            Text(
              event.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Informações do evento
            _buildInfoRow(Icons.calendar_today, 'Data', DateFormat('dd/MM/yyyy').format(event.startDate)),
            _buildInfoRow(Icons.access_time, 'Horário', DateFormat('HH:mm').format(event.startDate)),
            if (event.location != null)
              _buildInfoRow(Icons.location_on, 'Local', event.location!),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Preço
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isFree ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFree ? Colors.green : Colors.blue,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isFree ? Icons.card_giftcard : Icons.attach_money,
                    size: 48,
                    color: isFree ? Colors.green[700] : Colors.blue[700],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFree ? 'EVENTO GRATUITO' : 'EVENTO PAGO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isFree ? Colors.green[800] : Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFree 
                              ? 'Inscrição gratuita' 
                              : 'Valor: R\$ ${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isFree ? Colors.green[900] : Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Descrição
            if (event.description != null && event.description!.isNotEmpty) ...[
              const Text(
                'Sobre o Evento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                event.description!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
            ],

            // Botão de inscrição
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isRegistering ? null : () => _registerInEvent(event, member),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFree ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isRegistering
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isFree ? 'CONFIRMAR INSCRIÇÃO GRATUITA' : 'PROSSEGUIR PARA PAGAMENTO',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            if (!isFree) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'As opções de pagamento serão implementadas em breve. Por enquanto, o ingresso será gerado gratuitamente.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerInEvent(Event event, dynamic member) async {
    if (member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você precisa ter um perfil de membro para se inscrever')),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    // VIS-04 / T-08-01: pré-checagem de elegibilidade é UX — evita disparar
    // uma escrita que o servidor já vai recusar e explica o motivo na hora.
    // A AUTORIDADE continua sendo `register_member_in_event` (Plano 07); o
    // mapeamento de recusa no `catch` abaixo permanece OBRIGATÓRIO, porque a
    // elegibilidade pode mudar entre esta checagem e o envio.
    //
    // T-08-05: falha na pré-checagem NÃO bloqueia — em caso de erro segue e
    // deixa o servidor decidir, que é a autoridade real.
    bool elegivel = true;
    try {
      elegivel = await ref.read(amIEligibleToRegisterProvider(event.id).future);
    } catch (_) {
      elegivel = true;
    }
    if (!elegivel) {
      if (!mounted) return;
      setState(() => _isRegistering = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_copyNaoElegivel)));
      return;
    }

    try {
      // Registrar inscrição — qr_code é persistido pelo repositório
      // (determinístico por event_id+user_id), não gerado aqui, pra que o
      // mesmo código sobreviva a sair/voltar da tela.
      final registration = await ref
          .read(eventsRepositoryProvider)
          .registerMemberInEvent(eventId: event.id, memberId: member.id);

      // Invalidar providers
      ref.invalidate(eventRegistrationsProvider(event.id));
      ref.invalidate(eventByIdProvider(event.id));

      setState(() {
        _generatedTicket = EventTicket(
          id: registration.id,
          eventId: event.id,
          memberId: member.id,
          qrCode: registration.qrCode ?? 'EVENT_TICKET:${event.id}:${member.id}',
          status: 'paid', // Por enquanto sempre pago (mesmo gratuito)
          paidAmount: event.isFree ? 0 : event.price,
          createdAt: registration.registeredAt,
          paidAt: registration.registeredAt,
          eventName: event.name,
        );
        _isRegistering = false;
      });
    } catch (e) {
      setState(() {
        _isRegistering = false;
      });

      if (!mounted) return;

      // REG-04: esta tela nunca conta inscritos nem decide se há vaga — só
      // reage ao veredito da RPC. Quando o servidor recusa por capacidade,
      // mostra a copy PT-BR única e invalida evento e lista para o contador
      // convergir (T-07-04).
      if (isEventFullError(e)) {
        AppErrorHandler.log(e, feature: 'events');
        ref.invalidate(eventRegistrationsProvider(event.id));
        ref.invalidate(eventByIdProvider(event.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(eventFullMessage(event.maxCapacity))),
        );
        return;
      }

      // VIS-04: recusa por audiência (Plano 07). Convive com o tratamento de
      // `EVENT_FULL` que a Fase 1 estabeleceu, sem substituí-lo — ordem
      // preservada de propósito: lotação continua sendo checada primeiro.
      if (_recusaDoServidor(e, _codigoNaoElegivel)) {
        AppErrorHandler.log(e, feature: 'events');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(_copyNaoElegivel)));
        return;
      }

      AppErrorHandler.showSnackBar(
        context,
        e,
        feature: 'events',
        fallbackMessage:
            'Não foi possível concluir a inscrição. Tente novamente.',
      );
    }
  }

  Widget _buildTicketScreen(Event event, EventTicket ticket) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          'Seu Ingresso',
          style: CommunityDesign.titleStyle(context),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Ícone de sucesso
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),

            // Mensagem de sucesso
            const Text(
              'Inscrição Confirmada!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Seu ingresso foi gerado com sucesso',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Card do ingresso
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Nome do evento
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd/MM/yyyy - HH:mm').format(event.startDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.location!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300] ?? Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: ticket.qrCode,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instruções
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Apresente este QR Code na entrada do evento para fazer o check-in',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Botão de fechar
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CONCLUIR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
