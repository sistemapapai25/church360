import 'package:flutter/material.dart';

class QuickCategoryForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const QuickCategoryForm({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<QuickCategoryForm> createState() => _QuickCategoryFormState();
}

class _QuickCategoryFormState extends State<QuickCategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();

  String _tipo = 'DESPESA';
  String _grupo = 'administrativa';
  bool _ativa = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      widget.onSave({
        'name': _nomeController.text.trim(),
        'tipo': _tipo,
        'grupo': _grupo,
        'descricao': _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
        'ativa': _ativa,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.category, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text(
                    'Nova Categoria',
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
                          labelText: 'Nome da Categoria *',
                          hintText: 'Ex: Energia Elétrica, Dízimos, Manutenção',
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

                      // Tipo
                      DropdownButtonFormField<String>(
                        initialValue: _tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'DESPESA', child: Text('Despesa')),
                          DropdownMenuItem(value: 'RECEITA', child: Text('Receita')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _tipo = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Grupo
                      DropdownButtonFormField<String>(
                        initialValue: _grupo,
                        decoration: const InputDecoration(
                          labelText: 'Grupo',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'administrativa', child: Text('Administrativa')),
                          DropdownMenuItem(value: 'operacional', child: Text('Operacional')),
                          DropdownMenuItem(value: 'ministerial', child: Text('Ministerial')),
                          DropdownMenuItem(value: 'projetos', child: Text('Projetos')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _grupo = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Descrição
                      TextFormField(
                        controller: _descricaoController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          hintText: 'Ex: Despesas fixas de energia elétrica',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Ativa
                      SwitchListTile(
                        title: const Text('Categoria Ativa'),
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
                      backgroundColor: Colors.blue,
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
