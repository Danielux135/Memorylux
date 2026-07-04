import 'dart:convert';
import 'dart:io';

// resultado del envío: si falla, incluye el motivo real para poder
// diagnosticarlo (sin esto solo sabíamos "no se pudo enviar")
class FeedbackResult {
  final bool ok;
  final String? error;

  const FeedbackResult(this.ok, [this.error]);
}

// envía comentarios y reportes de bug al correo de daniel vía formsubmit,
// sin registro ni api key: el primer envío pide activar el correo una vez
class FeedbackService {
  static const _endpoint = 'https://formsubmit.co/ajax/contacto@danielux.es';

  static Future<FeedbackResult> send({
    required String type,
    required String message,
    String? email,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.contentType = ContentType.json;
      request.headers.set('accept', 'application/json');
      // formsubmit exige un Referer de página web real; sin él (como pasa
      // desde una app nativa) lo trata como "archivo local" y lo rechaza
      request.headers.set(HttpHeaders.refererHeader, 'https://danielux.es/');
      request.write(jsonEncode({
        '_subject': 'Memorylux · $type',
        'tipo': type,
        'mensaje': message,
        'email': (email == null || email.isEmpty) ? 'anónimo' : email,
        'plataforma': Platform.operatingSystem,
        'app': 'Memorylux 2.0.0',
      }));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return FeedbackResult(false, 'HTTP ${response.statusCode}: $body');
      }
      final decoded = jsonDecode(body);
      final ok = decoded['success'].toString() == 'true';
      return FeedbackResult(ok, ok ? null : body);
    } catch (e) {
      return FeedbackResult(false, e.toString());
    } finally {
      client.close();
    }
  }
}
