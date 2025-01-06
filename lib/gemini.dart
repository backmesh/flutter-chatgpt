import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_generative_ai/src/model.dart'
    show createModelWithBaseUri;
import 'package:nimbus/logger.dart';
import 'package:nimbus/user_store.dart';

// https://github.com/google-gemini/generative-ai-dart/tree/main/pkgs/google_generative_ai
// https://pub.dev/documentation/google_generative_ai/latest/google_generative_ai/google_generative_ai-library.html

final API_VERSION = 'v1beta';
final BASE_URL =
    'https://edge.backmesh.com/v1/proxy/PyHU4LvcdsQ4gm2xeniAFhMyuDl2/aUxjzrA9w7K9auXp6Be8';

class GeminiClient {
  late GenerativeModel client;

  static GeminiClient? _instance;

  GeminiClient._();

  static GeminiClient get instance {
    assert(_instance != null, 'Gemini must be initialized before accessing');
    return _instance!;
  }

  factory GeminiClient(String token, String model) {
    _instance = GeminiClient._();
    Uri uri = Uri.parse('$BASE_URL/$API_VERSION');
    _instance!.client = createModelWithBaseUri(
      model: model,
      apiKey: token,
      baseUri: uri,
    );
    return _instance!;
  }

  Stream<ChatResult> chatCompleteStream(
      List<Message> history, Message userMessage) async* {
    // add the sysmessage again here because otherwise it gets ignored often
    // not great because we are using up a lot of the context window
    List<Content> contents = [];
    for (var msg in history) {
      contents.add(await msg.toGemini());
    }
    final res = new ChatResult();
    final chat = client.startChat(history: contents);
    Logger.debug('START chat result for message ${userMessage.docKey()}');
    try {
      await for (var response
          in chat.sendMessageStream(await userMessage.toGemini())) {
        res.content += response.text ?? '';
        Logger.debug('ON chat result for message ${userMessage.docKey()}');
        // Logger.debug('Response: ${res.content}');
        yield res;
      }
      Logger.debug('END chat result for message ${userMessage.docKey()}');
    } catch (e) {
      Logger.debug('Error: $e'); // Log any errors
      rethrow; // Re-throw the error after logging it
    }
  }
}
