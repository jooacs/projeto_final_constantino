import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/questao.dart';

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

  /// Envia um PDF para a API do Gemini e solicita um quiz baseado nele
  Future<List<Questao>> generateQuizFromPdf(Uint8List pdfBytes, {int numberOfQuestions = 5}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Chave da API do Gemini não encontrada no arquivo .env. Verifique se a variável GEMINI_API_KEY está configurada corretamente.',
      );
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    final prompt = TextPart(
      "Você é um professor experiente criando um quiz. Analise este documento PDF e gere um quiz de múltipla escolha sobre o conteúdo principal com $numberOfQuestions perguntas. Cada pergunta DEVE ter 4 opções e indicar o índice correto (0 a 3). O formato de saída DEVE ser estritamente um array JSON contendo objetos, onde cada objeto tem os campos: 'pergunta' (string), 'opcoes' (array de 4 strings), e 'indiceRespostaCorreta' (int).",
    );
    final pdfPart = DataPart('application/pdf', pdfBytes);

    try {
      final response = await model.generateContent([
        Content.multi([prompt, pdfPart]),
      ]);
      final jsonText = response.text;
      if (jsonText == null || jsonText.isEmpty) {
        throw Exception("O Gemini não retornou nenhum texto.");
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonText);
      List<Questao> questoes = jsonList.map((json) => Questao.fromJson(json)).toList();
      
      // Embaralhar as questões
      questoes.shuffle();

      // Embaralhar opções e atualizar índice da resposta correta
      for (var questao in questoes) {
        String respostaCorreta = questao.opcoes[questao.indiceRespostaCorreta];
        questao.opcoes.shuffle();
        questao.indiceRespostaCorreta = questao.opcoes.indexOf(respostaCorreta);
      }
      return questoes;

    } catch (e) {
      throw Exception('Erro ao gerar quiz com a API do Gemini: $e');
    }
  }
}
