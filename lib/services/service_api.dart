import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/datos_temporales.dart';
import 'ranking_websocket_service.dart';

class ServiceApi extends ChangeNotifier {
  ServiceApi() {
    // La hidratación ocurre después de crear el proveedor; notifyListeners
    // publica los datos recuperados a las pantallas que ya estén suscritas.
    recarga();
  }

  /// Restaura caché local y, si existe una sesión guardada, sincroniza los
  /// datos que dependen del backend (perfil, ranking e historial).
  Future<void> recarga() async {
    try {
      final tokenGuardado = await _datosTemporales.obtenerToken();
      final datosGuardados = await _datosTemporales.obtenerDatos();
      if (tokenGuardado != null && datosGuardados != null) {
        _token = tokenGuardado;
        datos = datosGuardados;
        await _iniciarEscuchaRanking();
        await rankingProramas();
        notifyListeners();
      }

      final historialGuardado = await _datosTemporales.obtenerHistorial();
      if (historialGuardado != null) {
        historial = _conservarUltimosVeinte(historialGuardado);
        notifyListeners();
      }
      if (_token != null && _token!.isNotEmpty) {
        await verBusqueda();
        notifyListeners();
        print("___");
      }
    } catch (e) {}
  }

  // final _url = "http://10.4.61.161:8000/api";
  final _url = "https://caa-fonseca.education/api";
  final _datosTemporales = DatosTemporales();
  String? _token;
  RankingWebSocketService? _rankingSocket;
  StreamSubscription<Map<String, dynamic>>? _rankingSocketSubscription;
  bool _actualizandoDesdeSocket = false;
  bool _servicioCerrado = false;
  bool _cerrandoSesion = false;
  Map? datos;
  Map historial = {};

  /// Invalida primero el estado local para cerrar la sesión en la UI aunque
  /// falle la petición remota. Devuelve 200 si el backend confirma el cierre.
  Future<int> logout() async {
    final token = _token;
    _cerrandoSesion = true;
    _token = null;
    datos = null;
    await _detenerEscuchaRanking();
    await _datosTemporales.eliminarToken();
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      try {
        final url = Uri.parse("$_url/logout");
        final respuesta = await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        );
        if (respuesta.statusCode == 200) {
          await _datosTemporales.eliminarToken();
          print(
            "Cerraste sesion\n${respuesta.body}\n_________________________________",
          );
          notifyListeners();
          return 200;
        } else {
          print("Credenciales incorrectas\n${respuesta.body}");
          return 404;
        }
      } catch (e) {
        print("Error de conexión\n$e");
        return 404;
      }
    } else {
      return 404;
    }
  }

  /// Rehidrata token y perfil desde preferencias; no comprueba en el servidor
  /// si el token sigue vigente.
  Future<bool> restaurarSesion() async {
    if (_cerrandoSesion) return false;

    final token = await _datosTemporales.obtenerToken();
    final datosGuardados = await _datosTemporales.obtenerDatos();
    if (token == null || token.isEmpty || datosGuardados == null) {
      await _datosTemporales.eliminarToken();
      return false;
    }

    _token = token;
    datos = datosGuardados;
    notifyListeners();

    return true;
  }

  /// Intercambia documento y contraseña por un token y carga el perfil.
  /// Contrato interno actual: 200 = éxito, 401 = respuesta no exitosa del
  /// backend y 404 = excepción de conexión u otro fallo lanzado en la petición.
  Future<int> login(String document, String password) async {
    print("Logueandose");
    _cerrandoSesion = false;
    try {
      final url = Uri.parse("$_url/login");
      final respuesta = await http.post(
        url,
        body: jsonEncode({"user_name": document, "password": password}),
        headers: {"Content-Type": "application/json"},
      );
      print(respuesta.statusCode);
      if (respuesta.statusCode == 200) {
        _token = jsonDecode(respuesta.body)["token"];
        await _datosTemporales.guardarToken(_token!);
        await _iniciarEscuchaRanking();
        print(
          "Login exitoso\n${respuesta.body}\n_________________________________",
        );
        await user();
        notifyListeners();
        return 200;
      } else {
        print("Credenciales incorrectas\n${respuesta.body}\nestado: ${respuesta.statusCode}");
        return 401;
      }
    } catch (e) {
      print("Error de conexión\n$e");
      return 404;
    }
  }

  /// Obtiene el perfil autenticado, actualiza el estado compartido y lo guarda
  /// localmente para poder restaurar la sesión en el siguiente arranque.
  Future<Map> user() async {
    try {
      final url = Uri.parse("$_url/user");
      final respuesta = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
      );
      if (respuesta.statusCode == 200) {
        print("DATOS:\n${respuesta.body}\n___________________________");
        final data = jsonDecode(respuesta.body)["user"];
        if (data is! Map) {
          return {"respuesta": "sin dato"};
        }

        datos = data;
        await _datosTemporales.guardarDatos(data);
        notifyListeners();
        return data;
      } else {
        print("Credenciales incorrectas\n${respuesta.body}");
        return {"respuesta": "sin dato"};
      }
    } catch (e) {
      print("Error de conexión\n$e");
      return {"error": "$e"};
    }
  }

  /// Registra la respuesta de IA en el backend. Tras guardar, vuelve a pedir
  /// el historial para mantener el estado de la app alineado con el servidor.
  Future<bool> registrarBusqueda(Map mapa) async {
    if (_token == null || _token!.isEmpty) {
      print("No se pudo guardar la búsqueda: no hay token de sesión");
      return false;
    }

    try {
      final url = Uri.parse("$_url/busquedas");
      final respuesta = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(mapa),
      );

      print("Guardar búsqueda: ${respuesta.statusCode}\n${respuesta.body}");
      if (respuesta.statusCode == 201 || respuesta.statusCode == 200) {
        print("Dato agregado correctamente al historial ");
        await verBusqueda();
        return true;
      }
      return false;
    } catch (e) {
      print("Error al guardar la búsqueda\n$e");
      return false;
    }
  }

  /// Sincroniza el historial remoto; ante fallo conserva la última copia local.
  Future<void> verBusqueda() async {
    print("obteniendo...");
    try {
      final url = Uri.parse("$_url/historial");
      final respuesta = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
      );
      print("respuesta: ${respuesta.statusCode}\n ${respuesta.body}");
      final datosHistorial = jsonDecode(respuesta.body);
      if (respuesta.statusCode == 200 && datosHistorial is Map) {
        historial = _conservarUltimosVeinte(datosHistorial);
        await _datosTemporales.guardarHistorial(historial);
        notifyListeners();
      } else {
        await cargarHistorialGuardado();
      }
      // if(respuesta.statusCode==201 || respuesta.statusCode==200){
      //  print("Dato agregado correctamente al historial ");
      //  return;
      // }
    } catch (e) {
      print("error\n$e");
      await cargarHistorialGuardado();
    }
  }

  Map _conservarUltimosVeinte(Map datosHistorial) {
    final registros = datosHistorial["historial"];
    if (registros is! List) return datosHistorial;

    // Ordenar por fecha evita depender del orden que entregue el backend; la
    // misma ventana de 20 registros se usa tanto para UI como para la caché.
    final ordenados = registros.whereType<Map>().toList();
    ordenados.sort((a, b) {
      final fechaA =
          DateTime.tryParse('${a["fecha_registro"] ?? ""}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final fechaB =
          DateTime.tryParse('${b["fecha_registro"] ?? ""}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return fechaB.compareTo(fechaA);
    });

    return {...datosHistorial, "historial": ordenados.take(20).toList()};
  }

  /// Recupera la última copia local cuando el servicio remoto no responde.
  Future<void> cargarHistorialGuardado() async {
    final historialGuardado = await _datosTemporales.obtenerHistorial();
    if (historialGuardado == null) return;

    historial = _conservarUltimosVeinte(historialGuardado);
    notifyListeners();
  }

  Future<void> _iniciarEscuchaRanking() async {
    if (_servicioCerrado || _rankingSocket != null) return;

    final socket = RankingWebSocketService.pusherDashboard();
    _rankingSocket = socket;
    _rankingSocketSubscription = socket.actualizaciones.listen((mensaje) async {
      final event = mensaje['event']?.toString() ?? '';
      final data = mensaje['data'];

      if (event.startsWith('pusher') ||
          event.isEmpty && data is Map && data['programas'] == null && data['historial'] == null) {
        return;
      }

      if (_actualizandoDesdeSocket || _servicioCerrado) return;

      // El evento solo invalida los datos visibles: se vuelve a consultar la
      // fuente REST para que rankings e historial conserven su contrato actual.
      _actualizandoDesdeSocket = true;
      try {
        await rankingProramas();
        await verBusqueda();
      } finally {
        _actualizandoDesdeSocket = false;
      }
    });

    await socket.conectar();
  }

  Future<void> _detenerEscuchaRanking() async {
    await _rankingSocketSubscription?.cancel();
    await _rankingSocket?.dispose();
    _rankingSocketSubscription = null;
    _rankingSocket = null;
  }



  /// Carga el ranking agregado de programas desde la API institucional.
  List getProgramas = [];
  Future<void> rankingProramas()async{
    try {
      final url = Uri.parse("$_url/estadisticas/busquedas/programas");
      final respuesta = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
      );
      print("respuesta: ${respuesta.statusCode}\n ${respuesta.body}");
      // final datosHistorial = jsonDecode(respuesta.body);
      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body)["programas"];
        getProgramas = data is List ? data : [];
        notifyListeners();
      } else {
        // await cargarHistorialGuardado();
      }
      // if(respuesta.statusCode==201 || respuesta.statusCode==200){
      //  print("Dato agregado correctamente al historial ");
      //  return;
      // }
    } catch (e) {
      print("error\n$e");
      await cargarHistorialGuardado();
    }
  }
  /// Carga el ranking de fichas pertenecientes al programa indicado.
  List getFichas = [];
  Future<int> rankingFichas(int id)async{
    try {
      final url = Uri.parse("$_url/estadisticas/busquedas/programas/$id/fichas");
      final respuesta = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
      );
      print("respuesta: ${respuesta.statusCode}\n ${respuesta.body}");
      // final datosHistorial = jsonDecode(respuesta.body);
      if (respuesta.statusCode == 200) {
        final data = jsonDecode(respuesta.body)["fichas"];
        getFichas = data is List ? data : [];
        notifyListeners();
        return 200;
      } else {
        // await cargarHistorialGuardado();
        return 401;
      }
      // if(respuesta.statusCode==201 || respuesta.statusCode==200){
      //  print("Dato agregado correctamente al historial ");
      //  return;
      // }
    } catch (e) {
      print("error\n$e");
      await cargarHistorialGuardado();
      return 404;
    }
  }

  /// Calcula la posición de una ficha dentro del programa a partir de los
  /// resultados actuales, ordenados por cantidad de búsquedas descendente.
  Future<int?> puestoFichaEnPrograma({
    required String programa,
    required String numeroFicha,
  }) async {
    if (getProgramas.isEmpty) {
      await rankingProramas();
    }

    final programaBuscado = programa.trim().toLowerCase();
    Map? programaDatos;
    for (final item in getProgramas) {
      if (item is Map &&
          '${item["name"]}'.trim().toLowerCase() == programaBuscado) {
        programaDatos = item;
        break;
      }
    }
    if (programaDatos == null) return null;

    final idPrograma = int.tryParse('${programaDatos["id"]}');
    if (idPrograma == null || await rankingFichas(idPrograma) != 200) {
      return null;
    }

    final fichasOrdenadas = [...getFichas]
      ..sort((a, b) {
        final busquedasA = a is Map && a["total_busquedas"] is num
            ? a["total_busquedas"] as num
            : 0;
        final busquedasB = b is Map && b["total_busquedas"] is num
            ? b["total_busquedas"] as num
            : 0;
        return busquedasB.compareTo(busquedasA);
      });

    final indice = fichasOrdenadas.indexWhere(
      (ficha) =>
          ficha is Map &&
          '${ficha["number_cohort"]}'.trim() == numeroFicha.trim(),
    );
    return indice < 0 ? null : indice + 1;
  }

  /// Carga la ficha y su ranking de aprendices.
  List getFichaAprendiz = [];
  Map datosFicha = {};
  Future<int> rankingFichaAprendiz(int id)async{
    try {
      final url = Uri.parse("$_url/estadisticas/busquedas/fichas/$id/aprendices");
      final respuesta = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $_token",
          "Content-Type": "application/json",
        },
      );
      print("respuesta: ${respuesta.statusCode}\n ${respuesta.body}");
      // final datosHistorial = jsonDecode(respuesta.body);
      if (respuesta.statusCode == 200) {
        final dataF = jsonDecode(respuesta.body)["ficha"];
        final data = jsonDecode(respuesta.body)["aprendices"];
        datosFicha = dataF is Map ? dataF : {};
        getFichaAprendiz = data is List ? data : [];
        notifyListeners();
        return 200;
      } else {
        // await cargarHistorialGuardado();
        return 401;
      }
      // if(respuesta.statusCode==201 || respuesta.statusCode==200){
      //  print("Dato agregado correctamente al historial ");
      //  return;
      // }
    } catch (e) {
      print("error\n$e");
      await cargarHistorialGuardado();
      return 404;
    }
  }

  @override
  void dispose() {
    // Cierra la escucha y el socket junto con el ciclo de vida del proveedor.
    _servicioCerrado = true;
    unawaited(_detenerEscuchaRanking());
    super.dispose();
  }
}
