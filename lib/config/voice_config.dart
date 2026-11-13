import 'package:flutter_tts/flutter_tts.dart';

class VoiceConfig {
  static FlutterTts flutterTts = FlutterTts();

  /// Reproduce texto en inglés con la síntesis disponible en el dispositivo;
  /// esta función no captura ni evalúa la pronunciación del usuario.
  static Future<void> hablar(String dato) async {
    // debugPrint("Hablando...");
    try{
      await flutterTts.setLanguage(
        // !estado ? "es-ES" : "en-US"
        "en-US"
        );
      // await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.4);
      await flutterTts.setVolume(1);
      await flutterTts.setPitch(1.0);

      await flutterTts.speak(dato.isEmpty ? "Ingrese un texto" : dato);
    }catch(e){
      print("error\n$e");
    }
  }
}