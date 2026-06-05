import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  /// Envia um PDF para a API do Gemini e solicita um resumo
  Future<String> summarizePdf(Uint8List pdfBytes) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Chave da API do Gemini não encontrada no arquivo .env. Verifique se a variável GEMINI_API_KEY está configurada corretamente.',
      );
    }

    // O modelo gemini-1.5-flash é ótimo para tarefas multimodais rápidas e baratas
    final model = GenerativeModel(
      model: 'gemini-2.5-flash', // Atualizado para a versão mais recente!
      apiKey: apiKey,
    );

    final prompt = TextPart(
      "Você é um assistente de estudos. Por favor, analise este documento PDF e faça um resumo bem estruturado e fácil de entender, destacando os pontos principais. Responda em Português.",
    );
    final pdfPart = DataPart('application/pdf', pdfBytes);

    try {
      final response = await model.generateContent([
        Content.multi([prompt, pdfPart]),
      ]);
      return response.text ?? "O Gemini não retornou nenhum texto.";
    } catch (e) {
      throw Exception('Erro ao comunicar com a API do Gemini: $e');
    }
  }
}
