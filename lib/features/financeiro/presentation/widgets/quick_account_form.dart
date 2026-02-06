import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickAccountForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const QuickAccountForm({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<QuickAccountForm> createState() => _QuickAccountFormState();
}

class _QuickAccountFormState extends State<QuickAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _bancoController = TextEditingController();
  final _agenciaController = TextEditingController();
  final _contaController = TextEditingController();
  final _titularController = TextEditingController();
  final _saldoInicialController = TextEditingController(text: '0,00');

  String _tipoConta = 'bancaria';
  bool _ativa = true;
  bool _contaPrincipal = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _bancoController.dispose();
    _agenciaController.dispose();
    _contaController.dispose();
    _titularController.dispose();
    _saldoInicialController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      // Parse saldo inicial
      final saldoText = _saldoInicialController.text.replaceAll('.', '').replaceAll(',', '.');
      final saldo = double.tryParse(saldoText) ?? 0.0;

      widget.onSave({
        'nome': _nomeController.text.trim(),
        'tipo': _tipoConta,
        'instituicao': _bancoController.text.trim().isEmpty ? null : _bancoController.text.trim(),
        'agencia': _agenciaController.text.trim().isEmpty ? null : _agenciaController.text.trim(),
        'numero': _contaController.text.trim().isEmpty ? null : _contaController.text.trim(),
        'titular': _titularController.text.trim().isEmpty ? null : _titularController.text.trim(),
        'saldo_inicial': saldo,
        'ativa': _ativa,
        'conta_principal': _contaPrincipal,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text(
                    'Nova Conta Financeira',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome (obrigatório)
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Conta *',
                          hintText: 'Ex: Banco do Brasil - Conta Principal, Caixa Físico',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nome é obrigatório';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      // Tipo de Conta
                      DropdownButtonFormField<String>(
                        initialValue: _tipoConta,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Conta *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'bancaria', child: Text('Conta Bancária')),
                          DropdownMenuItem(value: 'caixa', child: Text('Caixa')),
                          DropdownMenuItem(value: 'pix', child: Text('PIX')),
                          DropdownMenuItem(value: 'investimento', child: Text('Investimento')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _tipoConta = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Banco
                      if (_tipoConta == 'bancaria' || _tipoConta == 'pix' || _tipoConta == 'investimento') ...[
                        TextFormField(
                          controller: _bancoController,
                          decoration: const InputDecoration(
                            labelText: 'Banco',
                            hintText: 'Ex: Banco do Brasil, Caixa Econômica',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Agência e Conta (apenas para bancária)
                      if (_tipoConta == 'bancaria') ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _agenciaController,
                                decoration: const InputDecoration(
                                  labelText: 'Agência',
                                  hintText: '0000',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _contaController,
                                decoration: const InputDecoration(
                                  labelText: 'Conta',
                                  hintText: '00000-0',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Titular
                        TextFormField(
                          controller: _titularController,
                          decoration: const InputDecoration(
                            labelText: 'Titular',
                            hintText: 'Nome do titular da conta',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Saldo Inicial
                      TextFormField(
                        controller: _saldoInicialController,
                        decoration: const InputDecoration(
                          labelText: 'Saldo Inicial',
                          hintText: '0,00',
                          border: OutlineInputBorder(),
                          prefixText: 'R\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Conta Principal
                      SwitchListTile(
                        title: const Text('Conta Principal'),
                        subtitle: const Text('Usar como padrão nos lançamentos'),
                        value: _contaPrincipal,
                        onChanged: (value) {
                          setState(() {
                            _contaPrincipal = value;
                          });
                        },
                      ),

                      // Ativa
                      SwitchListTile(
                        title: const Text('Conta Ativa'),
                        subtitle: const Text('Desative para ocultar sem apagar'),
                        value: _ativa,
                        onChanged: (value) {
                          setState(() {
                            _ativa = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleSave,
                    icon: const Icon(Icons.check),
                    label: const Text('Salvar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
