import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickBeneficiaryForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const QuickBeneficiaryForm({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<QuickBeneficiaryForm> createState() => _QuickBeneficiaryFormState();
}

class _QuickBeneficiaryFormState extends State<QuickBeneficiaryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _documentoController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _observacoesController = TextEditingController();

  String _tipoBeneficiario = 'pessoa_fisica';
  bool _ativo = true;

  final _cpfMask = _DigitMaskTextInputFormatter('###.###.###-##');
  final _cnpjMask = _DigitMaskTextInputFormatter('##.###.###/####-##');
  final _telefoneMask = _DigitMaskTextInputFormatter('(##) #####-####');

  @override
  void dispose() {
    _nomeController.dispose();
    _documentoController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      widget.onSave({
        'name': _nomeController.text.trim(),
        'documento': _documentoController.text.trim().isEmpty ? null : _documentoController.text.trim(),
        'phone': _telefoneController.text.trim().isEmpty ? null : _telefoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
        'tipo_beneficiario': _tipoBeneficiario,
        'ativo': _ativo,
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
                  const Icon(Icons.person_add, color: Colors.green),
                  const SizedBox(width: 12),
                  const Text(
                    'Novo Beneficiário',
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
                          labelText: 'Nome do Beneficiário *',
                          hintText: 'Ex: João da Silva, Empresa X, Ministério Infantil',
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

                      // Tipo de Beneficiário
                      DropdownButtonFormField<String>(
                        initialValue: _tipoBeneficiario,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Beneficiário *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pessoa_fisica', child: Text('Pessoa Física')),
                          DropdownMenuItem(value: 'pessoa_juridica', child: Text('Pessoa Jurídica')),
                          DropdownMenuItem(value: 'ministerio', child: Text('Ministério Interno')),
                          DropdownMenuItem(value: 'instituicao', child: Text('Instituição / Convênio')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _tipoBeneficiario = value!;
                            _documentoController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Documento (CPF/CNPJ)
                      TextFormField(
                        controller: _documentoController,
                        decoration: InputDecoration(
                          labelText: _tipoBeneficiario == 'pessoa_fisica' ? 'CPF' : 'CNPJ',
                          hintText: _tipoBeneficiario == 'pessoa_fisica' ? '000.000.000-00' : '00.000.000/0000-00',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _tipoBeneficiario == 'pessoa_fisica' ? _cpfMask : _cnpjMask,
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Telefone / WhatsApp
                      TextFormField(
                        controller: _telefoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefone / WhatsApp',
                          hintText: '(00) 00000-0000',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _telefoneMask,
                        ],
                      ),
                      const SizedBox(height: 16),

                      // E-mail
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          hintText: 'exemplo@email.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (!value.contains('@')) {
                              return 'E-mail inválido';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Observações
                      TextFormField(
                        controller: _observacoesController,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          hintText: 'Ex: Fornecedor fixo de energia, Ofertas especiais',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Ativo
                      SwitchListTile(
                        title: const Text('Beneficiário Ativo'),
                        subtitle: const Text('Desative para ocultar sem apagar'),
                        value: _ativo,
                        onChanged: (value) {
                          setState(() {
                            _ativo = value;
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
                      backgroundColor: Colors.green,
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

class _DigitMaskTextInputFormatter extends TextInputFormatter {
  final String mask;

  _DigitMaskTextInputFormatter(this.mask);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final masked = _applyMask(digits);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  String _applyMask(String digits) {
    if (digits.isEmpty) return '';
    final out = StringBuffer();
    var di = 0;
    for (var i = 0; i < mask.length; i++) {
      final m = mask[i];
      if (m == '#') {
        if (di >= digits.length) break;
        out.write(digits[di]);
        di++;
        continue;
      }
      if (di < digits.length) {
        out.write(m);
      } else {
        break;
      }
    }
    return out.toString();
  }
}
