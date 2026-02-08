import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  final String apiKey;
  AiService(this.apiKey);

  Future<String> analyzeEmail({
    required String prompt,
    required String subject,
    required String body,
  }) async {
    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
      final fullPrompt = "$prompt\n\n제목: $subject\n본문: $body";
      final response = await model.generateContent([Content.text(fullPrompt)]);
      return response.text ?? "결과 없음";
    } catch (e) {
      return "에러 발생: $e";
    }
  }
}
