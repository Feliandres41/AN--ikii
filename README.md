# ANüikii

Aplicación móvil hecha con Flutter para apoyar el aprendizaje de vocabulario técnico en inglés de los aprendices del SENA, especialmente en la Regional La Guajira. Esta primera versión reúne consulta de términos, una interfaz de reconocimiento visual y funciones institucionales relacionadas con el perfil y las búsquedas.

> **Estado de v1.0.0:** release inicial para pruebas y validación institucional, no para distribución amplia. El análisis visual con IA está temporalmente deshabilitado hasta integrarlo mediante un backend seguro; el backend institucional tampoco está incluido en este repositorio.

## ¿Para qué sirve la app?

Cuando el análisis visual esté habilitado, el aprendiz podrá enfocar un objeto con la cámara y consultar su nombre en español e inglés, una guía escrita de pronunciación y ejemplos de uso en pasado, presente y futuro. También podrá escuchar en inglés el término y las oraciones. La aplicación conserva un historial de consultas y muestra rankings institucionales de programas, fichas y aprendices.

El inicio de sesión permite asociar las búsquedas con el usuario institucional. En la pantalla de inicio se presenta información del perfil y, cuando hay datos disponibles, la posición de la ficha del aprendiz dentro del ranking del programa.

## Funcionalidades implementadas

- Inicio de sesión institucional y cierre de sesión.
- Restauración local de la sesión, perfil e historial.
- Inicio con información del perfil y glosario técnico de ejemplo.
- Interfaz de cámara para capturar un objeto; el análisis con IA está deshabilitado en este release.
- Pronunciación escrita, ejemplos en tres tiempos verbales y lectura en voz alta.
- Historial de términos consultados.
- Ranking por programas, fichas y aprendices.
- Tema claro/oscuro y pantalla de perfil/configuración.
- Indicador de conectividad de red.
- Pantallas de política de privacidad y términos y condiciones.

## Recorrido principal

1. El usuario inicia sesión con su número de documento y contraseña institucional.
2. Desde la navegación inferior abre la cámara y toma una foto del objeto.
3. **En esta versión, el análisis de la foto no está disponible.** Al reactivar la función mediante un backend seguro, la respuesta deberá incluir `objeto_esp`, `objeto_eng`, `pronunciacion`, `oracion_pasado`, `oracion_presente` y `oracion_futuro`.
4. Con el análisis habilitado, la app podrá presentar el resultado y registrarlo en el historial del usuario mediante el backend.
5. El usuario puede consultar su historial y explorar los rankings; la lectura en voz alta funciona cuando hay texto disponible.

Cuando se reactive el análisis, la respuesta de IA se procesará como JSON; si el proveedor devuelve texto que no pueda decodificarse, la consulta no se mostrará correctamente. Para cambiar este contrato, coordinar los cambios entre el prompt, la pantalla de cámara y el backend.

## Requisitos para desarrollo

- Flutter SDK con una versión de Dart que satisfaga `^3.12.2` (ver [`pubspec.yaml`](./pubspec.yaml)).
- Android Studio o VS Code con las extensiones de Flutter y Dart.
- Para Android: Android SDK y Java 17, requeridos por la configuración Gradle del proyecto.
- Emulador o dispositivo Android con cámara para probar el flujo visual. Se recomienda probar en un dispositivo real.
- Acceso a internet, credenciales institucionales válidas y disponibilidad del backend y del proveedor de IA.
- Para compilar iOS: macOS, Xcode y CocoaPods.

## Preparar y ejecutar

Desde la raíz del proyecto:

```bash
flutter doctor
flutter pub get
flutter run
```

En un equipo con varios dispositivos, lista los destinos y selecciona uno:

```bash
flutter devices
flutter run -d <device-id>
```

La cámara requiere permiso del sistema. El emulador puede no tener una cámara utilizable; en ese caso, prueba el resto de la app o usa un dispositivo físico.

## Generar el APK Android

Para compilar un APK de release:

```bash
flutter build apk --release
```

El archivo se genera en:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Este APK es solamente el cliente móvil: necesita internet y el backend institucional para login, historial y rankings. El análisis con IA no estará disponible mientras siga deshabilitado. **No distribuir este build como versión pública:** la configuración Gradle actual firma `release` con la clave de depuración. Antes de una distribución, configurar firma de release, revisar permisos y configuración de red de Android, y validar la compilación en un dispositivo objetivo.

## Servicios y dependencias externas

| Servicio o componente | Uso en la app | Implementación |
|---|---|---|
| Backend institucional | Login, perfil, cierre de sesión, registro/consulta del historial y estadísticas para los rankings. | [`ServiceApi`](./lib/services/service_api.dart) usa `https://caa-fonseca.education/api`; las peticiones autenticadas envían el token como `Bearer`. |
| IA generativa de Google | Integración temporalmente deshabilitada en v1.0.0; la clave está vacía y las solicitudes no se autentican. | [`ModelIaConfig`](./lib/config/model_ia_config.dart) contiene el cliente preparado, pero no se debe añadir una clave en la app. Para reactivarlo, trasladar la llamada a un backend/proxy seguro. |
| WebSocket de rankings | Escucha actualizaciones del canal `programming.dashboard`; al recibirlas, actualiza rankings e historial. | [`RankingWebSocketService`](./lib/services/ranking_websocket_service.dart); vuelve a intentar la conexión tras una desconexión. |
| Voz del dispositivo | Lee en voz alta el término o la oración en inglés. | [`VoiceConfig`](./lib/config/voice_config.dart) usa `flutter_tts` con idioma `en-US`; depende de las voces disponibles en el dispositivo. |
| Almacenamiento local | Conserva token, datos del perfil e historial en el dispositivo para restaurar/mostrar datos guardados. | [`DatosTemporales`](./lib/models/datos_temporales.dart) usa `shared_preferences`. No es almacenamiento cifrado. |
| Conectividad | Distingue entre conexión, transición y falta de acceso real a internet. | [`NetworkService`](./lib/services/network_services.dart) combina `connectivity_plus` e `internet_connection_checker_plus`. |
| Estado y tema | Comparte estado de API, red y tema entre pantallas. | `Provider`, `ChangeNotifier`, [`ServiceApi`](./lib/services/service_api.dart), [`NetworkService`](./lib/services/network_services.dart) y [`ThemeApk`](./lib/themes/theme_apk.dart). |

### API que consume el cliente

La base actual está definida en [`lib/services/service_api.dart`](./lib/services/service_api.dart). Las rutas usadas por la app son:

| Método | Ruta | Uso |
|---|---|---|
| `POST` | `/login` | Iniciar sesión con `user_name` y `password`; recibe un token. |
| `GET` | `/user` | Obtener el usuario autenticado. La interfaz consulta, entre otros, `rol`, `programa` y `ficha`. |
| `POST` | `/logout` | Cerrar la sesión autenticada. |
| `POST` | `/busquedas` | Registrar una consulta generada desde la cámara. |
| `GET` | `/historial` | Obtener el historial del usuario. La app conserva hasta 20 registros para mostrar. |
| `GET` | `/estadisticas/busquedas/programas` | Obtener el ranking de programas. |
| `GET` | `/estadisticas/busquedas/programas/{id}/fichas` | Obtener el ranking de fichas de un programa. |
| `GET` | `/estadisticas/busquedas/fichas/{id}/aprendices` | Obtener el ranking de aprendices de una ficha. |

El backend es un proyecto aparte y no forma parte de este repositorio. Antes de cambiar rutas, autenticación o el formato de los datos, confirmar el contrato con el equipo responsable del backend. Actualmente la URL del backend y la conexión WebSocket están definidas en el código; no hay una configuración por ambientes documentada en el proyecto.

## Estructura del código

```text
lib/
├── main.dart                 # Arranque y registro de proveedores globales
├── config/                   # IA, voz y utilidades de diseño adaptable
├── models/                   # Persistencia local y modelos
├── router/                   # Rutas principales de navegación
├── screens/                  # Pantallas de la app
├── scripts/                  # Instrucciones/prompt enviado a la IA
├── services/                 # API HTTP, WebSocket y conectividad
├── themes/                   # Estado y configuración visual
└── widget/                   # Componentes reutilizables
```

Las rutas principales se registran en [`lib/router/router_app.dart`](./lib/router/router_app.dart). [`main.dart`](./lib/main.dart) crea los proveedores compartidos para API, tema y conectividad. El paquete Dart todavía se llama `flutter_application_1` en [`pubspec.yaml`](./pubspec.yaml); los imports usan ese nombre, por lo que cambiarlo requiere actualizar también esos imports.

## Archivos útiles para empezar

- [`lib/screens/`](./lib/screens/): flujo y presentación de las pantallas.
- [`lib/services/service_api.dart`](./lib/services/service_api.dart): comunicación con el backend y estado de usuario, historial y rankings.
- [`lib/services/ranking_websocket_service.dart`](./lib/services/ranking_websocket_service.dart): conexión en tiempo real para actualizaciones del dashboard.
- [`lib/config/model_ia_config.dart`](./lib/config/model_ia_config.dart) y [`lib/scripts/ia_scripts.dart`](./lib/scripts/ia_scripts.dart): solicitud de análisis visual y formato esperado de la respuesta.
- [`lib/config/voice_config.dart`](./lib/config/voice_config.dart): síntesis de voz.
- [`lib/models/datos_temporales.dart`](./lib/models/datos_temporales.dart): persistencia local.
- [`pubspec.yaml`](./pubspec.yaml): versión, dependencias y recursos de Flutter.
- [`android/app/src/main/AndroidManifest.xml`](./android/app/src/main/AndroidManifest.xml): configuración y permiso de cámara en Android.

## Validación local

Antes de entregar cambios, ejecuta:

```bash
flutter analyze
flutter test
```

Las pruebas existentes están en [`test/`](./test/). Además de las comprobaciones automatizadas, probar manualmente login, permiso y captura de cámara, respuesta de IA, lectura de voz, historial y rankings; varias de estas funciones necesitan servicios externos y una cuenta válida.

## Mejoras posibles para futuras versiones

Estas ideas no están implementadas en la versión actual; deben planificarse y validarse con los usuarios y el equipo institucional:

- **Evaluación de pronunciación por audio:** permitir que el aprendiz grabe una palabra o frase en inglés y usar reconocimiento de voz o un servicio especializado de evaluación para comparar lo pronunciado con el texto esperado. La app podría señalar palabras que no se reconocieron y ofrecer sugerencias para repetirlas. Hoy la app solo reproduce audio con síntesis de voz; no graba ni califica la pronunciación del usuario.
- **Práctica guiada:** agregar ejercicios, repetición espaciada, metas de aprendizaje y seguimiento del progreso individual.
- **Glosario ampliable:** permitir buscar términos, navegar por categorías técnicas y guardar favoritos; actualmente el glosario inicial mostrado en home contiene ejemplos incluidos en la app.
- **Mayor resiliencia:** mejorar la experiencia sin conexión, los estados de carga y los mensajes cuando la API o la IA no estén disponibles.
- **Configuración por ambientes y seguridad:** separar desarrollo, pruebas y producción; mover secretos fuera de la aplicación cliente; usar almacenamiento seguro para la sesión y preparar una firma de release.
- **Pruebas automatizadas:** ampliar pruebas unitarias y de widgets, y añadir pruebas de integración para login, cámara, historial y rankings.

Para cualquier función de audio, definir primero consentimiento y permisos de micrófono, cómo se almacenan o eliminan las grabaciones, y si el procesamiento se hace en el dispositivo o se envía a un servicio externo.

## Consideraciones antes de continuar o distribuir

- **Credenciales de IA:** la credencial expuesta fue revocada y se retiró del snapshot publicado. No agregar una clave de reemplazo al cliente; reactivar el análisis solo mediante un backend/proxy seguro.
- **Datos personales e imágenes:** antes de reactivar el análisis, revisar autorización, consentimiento, tratamiento y retención de imágenes y asegurar que la app no envíe credenciales al proveedor desde el cliente.
- **Firma y red:** release aún usa firma debug y Android tiene habilitado tráfico HTTP sin cifrar. Revisar y endurecer la configuración de producción antes de distribuir.
- **Datos locales:** SharedPreferences no cifra el token ni los datos persistidos. Considerar almacenamiento seguro y una política de expiración de sesión antes de un despliegue institucional.
- **Entornos:** no existe separación documentada entre desarrollo, pruebas y producción. No cambiar el host de API o WebSocket por una URL local sin confirmar cómo accederá el dispositivo o emulador.
- **Dependencias:** evitar actualizar dependencias en bloque sin revisar cambios incompatibles y volver a ejecutar análisis, pruebas y validación manual.

## Versión

La versión declarada en [`pubspec.yaml`](./pubspec.yaml) es `1.0.0+1`. El proyecto se encuentra en su primera versión y requiere validación funcional, técnica e institucional antes de una publicación amplia.
