import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modelo de endereço retornado pela API ViaCEP
class ViaCepAddress {
  final String cep;
  final String logradouro; // Endereço
  final String complemento;
  final String bairro;
  final String localidade; // Cidade
  final String uf; // Estado
  final bool erro; // Se houve erro na busca

  ViaCepAddress({
    required this.cep,
    required this.logradouro,
    required this.complemento,
    required this.bairro,
    required this.localidade,
    required this.uf,
    this.erro = false,
  });

  factory ViaCepAddress.fromJson(Map<String, dynamic> json) {
    return ViaCepAddress(
      cep: json['cep'] ?? '',
      logradouro: json['logradouro'] ?? '',
      complemento: json['complemento'] ?? '',
      bairro: json['bairro'] ?? '',
      localidade: json['localidade'] ?? '',
      uf: json['uf'] ?? '',
      erro: json['erro'] == true,
    );
  }
}

/// Serviço para buscar endereço pelo CEP usando a API ViaCEP
class ViaCepService {
  static const String _baseUrl = 'https://viacep.com.br/ws';

  /// Buscar endereço pelo CEP
  /// 
  /// Retorna um [ViaCepAddress] com os dados do endereço
  /// 
  /// Lança exceção se:
  /// - CEP for inválido (não tiver 8 dígitos)
  /// - Não conseguir conectar à API
  /// - CEP não for encontrado
  static Future<ViaCepAddress> fetchAddress(String cep) async {
    // Remover caracteres não numéricos do CEP
    final cleanCep = cep.replaceAll(RegExp(r'[^0-9]'), '');

    // Validar CEP (deve ter 8 dígitos)
    if (cleanCep.length != 8) {
      throw Exception('CEP inválido. Deve conter 8 dígitos.');
    }

    try {
      // Fazer requisição para a API ViaCEP
      final url = Uri.parse('$_baseUrl/$cleanCep/json/');
      final response = await http.get(url);

      // Verificar se a requisição foi bem-sucedida
      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar CEP. Código: ${response.statusCode}');
      }

      // Decodificar resposta JSON
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Criar objeto ViaCepAddress
      final address = ViaCepAddress.fromJson(json);

      // Verificar se houve erro (CEP não encontrado)
      if (address.erro) {
        throw Exception('CEP não encontrado.');
      }

      return address;
    } catch (e) {
      // Re-lançar exceção com mensagem mais amigável
      if (e.toString().contains('CEP')) {
        rethrow;
      }
      throw Exception('Erro ao buscar CEP. Verifique sua conexão com a internet.');
    }
  }

  /// Formatar CEP no padrão brasileiro (00000-000)
  static String formatCep(String cep) {
    final cleanCep = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanCep.length != 8) return cep;
    return '${cleanCep.substring(0, 5)}-${cleanCep.substring(5)}';
  }

  /// Validar se o CEP tem formato válido
  static bool isValidCep(String cep) {
    final cleanCep = cep.replaceAll(RegExp(r'[^0-9]'), '');
    return cleanCep.length == 8;
  }
}

