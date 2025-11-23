import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/event.dart';
import '../providers/events_provider.dart';
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
  bool _isRegistering = false;
  EventTicket? _generatedTicket;

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

        // Se já gerou o ingresso, mostra a tela de sucesso
        if (_generatedTicket != null) {
          return _buildTicketScreen(event, _generatedTicket!);
        }

        // Senão, mostra a tela de inscrição
        return currentMemberAsync.when(
          data: (member) {
            if (member == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Inscrição no Evento')),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Você precisa ter um perfil de membro para se inscrever em eventos',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            }
            return _buildRegistrationScreen(event, member);
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Carregando...')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            appBar: AppBar(title: const Text('Erro')),
            body: Center(child: Text('Erro ao carregar perfil: $error')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(child: Text('Erro ao carregar evento: $error')),
      ),
    );
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

    try {
      // Gerar QR Code único
      final uuid = const Uuid();
      final ticketId = uuid.v4();
      final qrCode = 'EVENT_TICKET:${event.id}:${member.id}:$ticketId';

      // Criar ingresso
      final ticket = EventTicket(
        id: ticketId,
        eventId: event.id,
        memberId: member.id,
        qrCode: qrCode,
        status: 'paid', // Por enquanto sempre pago (mesmo gratuito)
        paidAmount: event.isFree ? 0 : event.price,
        createdAt: DateTime.now(),
        paidAt: DateTime.now(),
        eventName: event.name,
      );

      // Salvar no banco (TODO: implementar no repository)
      // await ref.read(eventsRepositoryProvider).createTicket(ticket);

      // Registrar inscrição
      await ref.read(eventsRepositoryProvider).addRegistration(event.id, member.id);

      // Invalidar providers
      ref.invalidate(eventRegistrationsProvider(event.id));
      ref.invalidate(eventByIdProvider(event.id));

      setState(() {
        _generatedTicket = ticket;
        _isRegistering = false;
      });
    } catch (e) {
      setState(() {
        _isRegistering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao realizar inscrição: $e')),
        );
      }
    }
  }

  Widget _buildTicketScreen(Event event, EventTicket ticket) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu Ingresso'),
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
                        color: Colors.grey[300]!,
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
