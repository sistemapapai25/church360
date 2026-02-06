import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/design/community_design.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../ministries/domain/models/ministry.dart';

class ScaleHistoryScreen extends ConsumerStatefulWidget {
  final String ministryId;

  const ScaleHistoryScreen({super.key, required this.ministryId});

  @override
  ConsumerState<ScaleHistoryScreen> createState() => _ScaleHistoryScreenState();
}

class _ScaleHistoryScreenState extends ConsumerState<ScaleHistoryScreen> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final ministryAsync = ref.watch(ministryByIdProvider(widget.ministryId));
    final schedulesAsync = ref.watch(ministrySchedulesProvider(widget.ministryId));

    return ministryAsync.when(
      data: (ministry) {
        final title = ministry?.name ?? 'Ministério';
        return Scaffold(
          appBar: AppBar(
            title: Text('Histórico de Escala • $title'),
            actions: [
              IconButton(
                tooltip: 'Gerar PDF',
                onPressed: _isGenerating ? null : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isGenerating = true);
                  try {
                    final schedules = await ref.read(ministrySchedulesProvider(widget.ministryId).future);
                    final bytes = await _generatePdf(title, schedules);
                    await Printing.sharePdf(bytes: bytes, filename: 'escala_$title.pdf');
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
                  } finally {
                    if (mounted) setState(() => _isGenerating = false);
                  }
                },
                icon: _isGenerating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf),
              ),
            ],
          ),
          body: schedulesAsync.when(
            data: (schedules) {
              if (schedules.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text('Nenhuma escala registrada para este ministério'),
                    ],
                  ),
                );
              }

              final Map<String, List<MinistrySchedule>> byEvent = {};
              for (final s in schedules) {
                byEvent.putIfAbsent(s.eventId, () => []).add(s);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(ministrySchedulesProvider(widget.ministryId));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...byEvent.entries.map((entry) {
                      final eventSchedules = entry.value;
                      final eventName = eventSchedules.first.eventName;
                      final dateStr = _formatDate(eventSchedules.first.createdAt);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: CommunityDesign.overlayDecoration(
                          Theme.of(context).colorScheme,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0x1A2196F3),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(CommunityDesign.radius),
                                  topRight: Radius.circular(CommunityDesign.radius),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      eventName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...eventSchedules.map(
                              (s) => ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(s.memberName),
                                subtitle: s.notes != null ? Text(s.notes!) : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro ao carregar histórico: $e')),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Erro: $e'))),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  Future<Uint8List> _generatePdf(String ministryName, List<MinistrySchedule> schedules) async {
    final doc = pw.Document();
    final grouped = <String, List<MinistrySchedule>>{};
    for (final s in schedules) {
      grouped.putIfAbsent(s.eventName, () => []).add(s);
    }
    doc.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Header(level: 0, child: pw.Text('Escala - $ministryName', style: pw.TextStyle(fontSize: 22))),
            ...grouped.entries.map((entry) {
              final rows = <pw.TableRow>[
                pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Membro', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Função/Notas', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ]),
                ...entry.value.map((s) => pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s.memberName)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s.notes ?? '—')),
                    ])),
              ];
              return pw.Column(children: [
                pw.SizedBox(height: 12),
                pw.Text(entry.key, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Table(border: pw.TableBorder.all(width: 0.5), children: rows),
              ]);
            }),
          ];
        },
      ),
    );
    return doc.save();
  }
}
