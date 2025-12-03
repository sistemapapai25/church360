import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/dashboard_widget_provider.dart';
import '../../domain/enums/report_enums.dart';
import '../../domain/models/custom_report.dart';
import '../../domain/models/report_config.dart';
import '../../domain/models/metric_template.dart';
import '../../domain/metadata/data_source_metadata.dart';
import '../providers/custom_report_providers.dart';

/// Tela de criação/edição de relatório customizado (Wizard)
class CustomReportBuilderScreen extends ConsumerStatefulWidget {
  final String? reportId; // null = criar, não-null = editar

  const CustomReportBuilderScreen({super.key, this.reportId});

  @override
  ConsumerState<CustomReportBuilderScreen> createState() => _CustomReportBuilderScreenState();
}

class _CustomReportBuilderScreenState extends ConsumerState<CustomReportBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  int _currentStep = 0;
  final int _totalSteps = 6; // MUDOU: 5 -> 6 (adicionado step de métrica)

  // Step 0: Informações Básicas
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Step 1: Fonte de Dados
  DataSource? _selectedDataSource;

  // Step 2: Métrica e Agrupamento (NOVO)
  MetricTemplate? _selectedMetric;
  GroupByOption? _selectedGroupBy;

  // Step 3: Tipo de Visualização Principal
  VisualizationType? _selectedVisualization;

  // Step 4: Múltiplas Visualizações
  List<ReportVisualization> _visualizations = [];

  // Step 5: Resumo
  ReportConfig _config = const ReportConfig();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Adicionar listeners para atualizar o estado quando o texto mudar
    _nameController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));

    if (widget.reportId != null) {
      _loadReport();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(customReportRepositoryProvider);
      final report = await repository.getReportById(widget.reportId!);

      if (report != null && mounted) {
        setState(() {
          _nameController.text = report.name;
          _descriptionController.text = report.description ?? '';
          _selectedDataSource = report.dataSource;
          _selectedVisualization = report.visualizationType;
          _visualizations = List.from(report.config.visualizations); // NOVO
          _config = report.config; // NOVO
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar relatório: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportId != null ? 'Editar Relatório' : 'Novo Relatório'),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Voltar'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Indicador de progresso
                _buildProgressIndicator(),
                
                // Conteúdo do step atual
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep0BasicInfo(), // Step 0
                      _buildStep1DataSource(), // Step 1
                      _buildStep2MetricAndGrouping(), // Step 2 (NOVO)
                      _buildStep3Visualization(), // Step 3
                      _buildStep4MultipleVisualizations(), // Step 4
                      _buildStep5Preview(), // Step 5
                    ],
                  ),
                ),

                // Botões de navegação
                _buildNavigationButtons(),
              ],
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (index < _totalSteps - 1) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep0BasicInfo() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Informações Básicas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Defina o nome e descrição do seu relatório',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // Nome
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome do Relatório *',
              hintText: 'Ex: Membros por Gênero',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.assessment),
            ),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nome é obrigatório';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Descrição
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              hintText: 'Descreva o objetivo deste relatório',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStep1DataSource() {
    final availableSources = DataSourceMetadataRegistry.availableDataSources;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Fonte de Dados',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha qual tipo de dado você quer analisar',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        ...availableSources.map((source) {
          final isSelected = _selectedDataSource == source;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDataSource = source;
                  // Reset métrica e agrupamento ao mudar fonte de dados
                  _selectedMetric = null;
                  _selectedGroupBy = null;
                  // Reset visualização se não for compatível
                  if (_selectedVisualization != null) {
                    final isCompatible = DataSourceMetadataRegistry.isVisualizationSupported(
                      source,
                      _selectedVisualization!,
                    );
                    if (!isCompatible) {
                      _selectedVisualization = null;
                    }
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.storage,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[600],
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.label,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            source.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep2MetricAndGrouping() {
    if (_selectedDataSource == null) {
      return const Center(
        child: Text('Selecione uma fonte de dados primeiro'),
      );
    }

    final availableMetrics = MetricTemplates.getTemplatesForDataSource(_selectedDataSource!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Métrica e Agrupamento',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Defina o que você quer medir e como agrupar os dados',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        // Seleção de Métrica
        Text(
          'O que você quer medir?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        ...availableMetrics.map((metric) {
          final isSelected = _selectedMetric?.id == metric.id;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedMetric = metric;
                  // Reset agrupamento ao mudar métrica
                  _selectedGroupBy = null;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _getMetricIcon(metric.aggregationType),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[600],
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.label,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),

        if (_selectedMetric != null) ...[
          const SizedBox(height: 24),

          // Seleção de Agrupamento
          Text(
            'Como você quer agrupar os dados?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          ..._selectedMetric!.groupByOptions.map((groupBy) {
            final isSelected = _selectedGroupBy?.type == groupBy.type &&
                _selectedGroupBy?.fieldName == groupBy.fieldName;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedGroupBy = groupBy;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _getGroupByIcon(groupBy.type),
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.grey[600],
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          groupBy.label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : null,
                              ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildStep3Visualization() {
    if (_selectedDataSource == null) {
      return const Center(
        child: Text('Selecione uma fonte de dados primeiro'),
      );
    }

    final metadata = DataSourceMetadataRegistry.getMetadata(_selectedDataSource!);
    final supportedVisualizations = metadata?.supportedVisualizations ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tipo de Visualização',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Como você quer visualizar os dados?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        ...supportedVisualizations.map((viz) {
          final isSelected = _selectedVisualization == viz;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedVisualization = viz;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _getVisualizationIcon(viz, isSelected),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viz.label,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            viz.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep4MultipleVisualizations() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Múltiplas Visualizações',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Adicione múltiplos gráficos ao seu relatório (opcional)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        // Lista de visualizações adicionadas
        if (_visualizations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.add_chart,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma visualização adicional',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Clique no botão abaixo para adicionar gráficos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._visualizations.asMap().entries.map((entry) {
            final index = entry.key;
            final viz = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  _getVisualizationIconData(viz.type),
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(viz.title),
                subtitle: Text(viz.type.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editVisualization(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeVisualization(index),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        // Botão para adicionar visualização
        ElevatedButton.icon(
          onPressed: _addVisualization,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar Visualização'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Preview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Resumo',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Revise as configurações do seu relatório',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        _buildSummaryCard(
          'Nome',
          _nameController.text.isEmpty ? 'Não definido' : _nameController.text,
          Icons.assessment,
        ),

        if (_descriptionController.text.isNotEmpty)
          _buildSummaryCard(
            'Descrição',
            _descriptionController.text,
            Icons.description,
          ),

        _buildSummaryCard(
          'Fonte de Dados',
          _selectedDataSource?.label ?? 'Não selecionada',
          Icons.storage,
        ),

        _buildSummaryCard(
          'Visualização Principal',
          _selectedVisualization?.label ?? 'Não selecionada',
          Icons.bar_chart,
        ),

        if (_visualizations.isNotEmpty)
          _buildSummaryCard(
            'Visualizações Adicionais',
            '${_visualizations.length} gráfico(s)',
            Icons.add_chart,
          ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Voltar'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _canProceed() ? _nextStep : null,
              child: Text(_currentStep == _totalSteps - 1 ? 'Salvar' : 'Próximo'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Informações Básicas
        return _nameController.text.trim().isNotEmpty;
      case 1: // Fonte de Dados
        return _selectedDataSource != null;
      case 2: // Métrica e Agrupamento
        return _selectedMetric != null && _selectedGroupBy != null;
      case 3: // Visualização Principal
        return _selectedVisualization != null;
      case 4: // Múltiplas Visualizações (opcional)
        return true; // Sempre pode prosseguir (é opcional)
      case 5: // Resumo/Salvar
        return true; // Pode salvar
      default:
        return false;
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    debugPrint('🔵 _nextStep chamado! Current step: $_currentStep, Total steps: $_totalSteps');
    debugPrint('🔵 Condição: $_currentStep < ${_totalSteps - 1} = ${_currentStep < _totalSteps - 1}');

    if (_currentStep < _totalSteps - 1) {
      if (_currentStep == 0 && !_formKey.currentState!.validate()) {
        debugPrint('❌ Form inválido no step 0!');
        return;
      }

      debugPrint('🟢 Avançando para próximo step...');
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      debugPrint('🟢 Último step! Chamando _saveReport...');
      _saveReport();
    }
  }

  Future<void> _saveReport() async {
    debugPrint('🔵 _saveReport chamado!');
    debugPrint('🔵 DataSource: $_selectedDataSource');
    debugPrint('🔵 Visualization: $_selectedVisualization');
    debugPrint('🔵 Nome: ${_nameController.text}');

    // Validar campos obrigatórios manualmente (Form não está mais na árvore)
    if (_nameController.text.trim().isEmpty) {
      debugPrint('❌ Nome vazio!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nome do relatório é obrigatório'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_selectedDataSource == null || _selectedVisualization == null) {
      debugPrint('❌ DataSource ou Visualization null!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione a fonte de dados e o tipo de visualização'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('🟢 Criando config...');

      // Criar agregação a partir da métrica e agrupamento selecionados
      final aggregation = _selectedMetric != null && _selectedGroupBy != null
          ? _selectedMetric!.toAggregation(
              groupBy: _selectedGroupBy!.type,
              groupByField: _selectedGroupBy!.fieldName,
            )
          : null;

      debugPrint('🟢 Agregação criada: ${aggregation?.label}');

      // Criar config com as visualizações e agregação
      final configWithData = _config.copyWith(
        visualizations: _visualizations,
        aggregations: aggregation != null ? [aggregation] : [],
      );

      debugPrint('🟢 Criando report object...');
      final report = CustomReport(
        id: widget.reportId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dataSource: _selectedDataSource!,
        visualizationType: _selectedVisualization!,
        config: configWithData,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      String? createdReportId;

      if (widget.reportId != null) {
        debugPrint('🟢 Atualizando relatório...');
        // Atualizar
        final update = ref.read(updateCustomReportProvider);
        await update(report);
        createdReportId = widget.reportId;
        debugPrint('✅ Relatório atualizado!');
      } else {
        debugPrint('🟢 Criando novo relatório...');
        // Criar
        final create = ref.read(createCustomReportProvider);
        final createdReport = await create(report);
        createdReportId = createdReport.id;
        debugPrint('✅ Relatório criado! ID: $createdReportId');

        // PASSO 2: Criar widget no dashboard automaticamente
        try {
          debugPrint('🟢 Criando widget no dashboard...');
          final createWidget = ref.read(createCustomDashboardWidgetProvider);

          // PASSO 3: Usar categoria automática baseada na fonte de dados
          final category = report.dataSource.dashboardCategory;
          debugPrint('🟢 Categoria automática: $category');

          await createWidget(
            widgetKey: 'custom_report_$createdReportId',
            widgetName: report.name,
            description: report.description ?? 'Relatório customizado',
            category: category,
            iconName: 'assessment',
            isEnabled: true,
          );
          debugPrint('✅ Widget criado no dashboard!');
        } catch (e) {
          // Se falhar ao criar widget, apenas loga mas não impede o fluxo
          debugPrint('⚠️ Erro ao criar widget no dashboard: $e');
        }
      }

      if (mounted) {
        debugPrint('✅ Mostrando snackbar e fechando tela...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.reportId != null
                  ? 'Relatório atualizado com sucesso!'
                  : 'Relatório criado e adicionado ao Dashboard!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERRO ao salvar: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar relatório: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Métodos para gerenciar múltiplas visualizações
  void _addVisualization() {
    showDialog(
      context: context,
      builder: (context) => _VisualizationDialog(
        dataSource: _selectedDataSource,
        onSave: (visualization) {
          setState(() {
            _visualizations.add(visualization);
          });
        },
      ),
    );
  }

  void _editVisualization(int index) {
    showDialog(
      context: context,
      builder: (context) => _VisualizationDialog(
        dataSource: _selectedDataSource,
        visualization: _visualizations[index],
        onSave: (visualization) {
          setState(() {
            _visualizations[index] = visualization;
          });
        },
      ),
    );
  }

  void _removeVisualization(int index) {
    setState(() {
      _visualizations.removeAt(index);
    });
  }

  IconData _getVisualizationIconData(VisualizationType viz) {
    switch (viz.value) {
      case 'pie':
        return Icons.pie_chart;
      case 'bar':
      case 'horizontal_bar':
        return Icons.bar_chart;
      case 'line':
        return Icons.show_chart;
      case 'area':
        return Icons.area_chart;
      case 'table':
        return Icons.table_chart;
      case 'card':
      case 'kpi':
      case 'multi_card':
        return Icons.dashboard;
      case 'gauge':
        return Icons.speed;
      default:
        return Icons.assessment;
    }
  }

  Widget _getVisualizationIcon(VisualizationType viz, bool isSelected) {
    final iconData = _getVisualizationIconData(viz);
    Color color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey[600]!;

    return Icon(iconData, color: color, size: 32);
  }

  /// Ícone para tipo de métrica
  IconData _getMetricIcon(AggregationType type) {
    switch (type) {
      case AggregationType.count:
      case AggregationType.countDistinct:
        return Icons.numbers;
      case AggregationType.sum:
        return Icons.add_circle_outline;
      case AggregationType.avg:
        return Icons.analytics;
      case AggregationType.min:
        return Icons.arrow_downward;
      case AggregationType.max:
        return Icons.arrow_upward;
    }
  }

  /// Ícone para tipo de agrupamento
  IconData _getGroupByIcon(GroupByType type) {
    switch (type) {
      case GroupByType.none:
        return Icons.remove;
      case GroupByType.day:
        return Icons.today;
      case GroupByType.week:
        return Icons.date_range;
      case GroupByType.month:
        return Icons.calendar_month;
      case GroupByType.year:
        return Icons.calendar_today;
      case GroupByType.status:
        return Icons.check_circle_outline;
      case GroupByType.category:
        return Icons.category;
      case GroupByType.type:
        return Icons.label;
      case GroupByType.custom:
        return Icons.tune;
    }
  }
}

/// Dialog para adicionar/editar visualização
class _VisualizationDialog extends StatefulWidget {
  final DataSource? dataSource;
  final ReportVisualization? visualization;
  final Function(ReportVisualization) onSave;

  const _VisualizationDialog({
    required this.dataSource,
    this.visualization,
    required this.onSave,
  });

  @override
  State<_VisualizationDialog> createState() => _VisualizationDialogState();
}

class _VisualizationDialogState extends State<_VisualizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  VisualizationType? _selectedType;

  @override
  void initState() {
    super.initState();
    if (widget.visualization != null) {
      _titleController.text = widget.visualization!.title;
      _selectedType = widget.visualization!.type;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<VisualizationType> _getSupportedVisualizations() {
    if (widget.dataSource == null) return VisualizationType.values;

    final metadata = DataSourceMetadataRegistry.getMetadata(widget.dataSource!);
    return metadata?.supportedVisualizations ?? VisualizationType.values;
  }

  @override
  Widget build(BuildContext context) {
    final supportedViz = _getSupportedVisualizations();

    return AlertDialog(
      title: Text(widget.visualization != null ? 'Editar Visualização' : 'Nova Visualização'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  hintText: 'Ex: Gráfico de Barras',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Título é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownMenu<VisualizationType>(
                initialSelection: _selectedType,
                label: const Text('Tipo de Visualização *'),
                dropdownMenuEntries: supportedViz
                    .map((viz) => DropdownMenuEntry<VisualizationType>(
                          value: viz,
                          label: viz.label,
                        ))
                    .toList(),
                onSelected: (value) {
                  setState(() => _selectedType = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final visualization = ReportVisualization(
      id: widget.visualization?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _selectedType!,
      title: _titleController.text.trim(),
      order: widget.visualization?.order ?? 0,
    );

    widget.onSave(visualization);
    Navigator.of(context).pop();
  }

  
}
