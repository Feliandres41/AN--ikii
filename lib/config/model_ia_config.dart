import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/scripts/ia_scripts.dart';
import 'package:flutter_application_1/services/service_api.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';

class ModelIaConfig {
  static String _Key = "";
  static var mapa;
  static final _modelIa = GenerativeModel(
    model: 'gemini-3.5-flash-lite',
    apiKey: _Key,
  );

  /// Envía la captura al modelo multimodal, interpreta su JSON y registra la
  /// respuesta en el historial del usuario autenticado. La imagen se procesa
  /// desde el cliente; un resultado que no sea JSON válido devuelve null.
  static Future<Map?> mandarImagen(
    Uint8List imagenBytes,
    BuildContext context,
  ) async {
    print("___");
    final serviceApi = Provider.of<ServiceApi>(context, listen: false);
    try {
      final response = await _modelIa.generateContent([
        Content.multi([
          TextPart(
            // "Quiero que analices la imagen q te voy a mandar y solo enfocate en lo principal,e ignora lo q esta alrededor y dime que es el objeto",
            IaScripts.analisisDatos,
          ),
          DataPart('image/jpeg', imagenBytes),
        ]),
      ]);
      if (response != null) {
        String? respuesta = response.text;
        print("Dato obtenido correctamente\n${response.text}");
        mapa = jsonDecode(respuesta!);
        await serviceApi.registrarBusqueda(mapa);
        return mapa is Map ? mapa : null;
      }
    } catch (e) {
      print("Error\n$e\n____________________________");
    }
    return null;
  }
}
