import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============================================================================
// SERVICIO DE NOTIFICACIONES LOCALES
// ============================================================================
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    
    // Solicitar permisos en Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'dispensador_channel',
      'Dispensador Alertas',
      channelDescription: 'Notificaciones del dispensador de comida para mascotas',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // Notificaciones predefinidas
  static void notifyMascotaDetectada(String animal, double confianza) {
    final emoji = animal == 'perro' ? '🐕' : '🐈';
    showNotification(
      id: 1,
      title: '$emoji ¡${animal.toUpperCase()} Detectado!',
      body: 'Se ha detectado un $animal con ${confianza.toStringAsFixed(0)}% de confianza',
    );
  }

  static void notifyComidaDispensada(String animal) {
    final emoji = animal == 'perro' ? '🐕' : '🐈';
    showNotification(
      id: 2,
      title: '$emoji Comida Dispensada',
      body: 'Se ha dispensado comida para $animal correctamente',
    );
  }

  static void notifyPocaLuz() {
    showNotification(
      id: 3,
      title: '💡 Prendiendo Iluminación',
      body: 'Se detectó poca luz, activando focos automáticamente',
    );
  }

  static void notifyAlertaHumedad() {
    showNotification(
      id: 4,
      title: '⚠️ Alerta de Humedad',
      body: 'Se detectó humedad alta en el dispensador',
    );
  }
}

// ============================================================================
// CONFIGURACIÓN THINGER.IO -
// ============================================================================
class ThingerConfig {
  static const String THINGER_USER = 'jeanpoll';
  static const String DEVICE_ID = 'dispensador01';
  static const String ACCESS_TOKEN =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXYiOiJkaXNwZW5zYWRvcjAxIiwiaWF0IjoxNzY5MzExNDYxLCJqdGkiOiI2OTc1OGNlNTI4M2JhMDljNTYwOTY4NzUiLCJzdnIiOiJ1cy1lYXN0LmF3cy50aGluZ2VyLmlvIiwidXNyIjoiamVhbnBvbGwifQ.FiDQ3E7HT2zvkTm06apM12qya7jBs9V330KPpYwTLKU';

  // Configuración de Cámara IoT
  static const String CAMERA_DEVICE_ID = 'camara01';
  static const String CAMERA_TOKEN =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXYiOiJjYW1hcmEwMSIsImlhdCI6MTc2OTU0Mzk4MCwianRpIjoiNjk3OTE5MmMyODNiYTA5YzU2MGEwNjFmIiwic3ZyIjoidXMtZWFzdC5hd3MudGhpbmdlci5pbyIsInVzciI6ImplYW5wb2xsIn0.bBB6lHJrOXpljDWGjBqBAA0NlHoi5WUZhtUgjP6Po1c';

  // Token del Proyecto (para Buckets y todos los dispositivos)
  static const String THINGER_TOKEN =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJ0b2tlbl9wcm95ZWN0byIsInN2ciI6InVzLWVhc3QuYXdzLnRoaW5nZXIuaW8iLCJ1c3IiOiJqZWFucG9sbCJ9.teRg_U70rmGta9v9Q8dlLOaztxT0PSrVdREwc4r0Nkk';

  // Configuración del Data Bucket de Fotos
  static const String BUCKET_ID = 'fotos_mascotas';

  static String get readUrl =>
      'https://api.thinger.io/v2/users/$THINGER_USER/devices/$DEVICE_ID/datos_generales';

  static String get writeUrl =>
      'https://api.thinger.io/v2/users/$THINGER_USER/devices/$DEVICE_ID/control_motor';

  static String cameraUrl(int timestamp) =>
      'https://api.thinger.io/v2/users/$THINGER_USER/devices/$CAMERA_DEVICE_ID/foto?t=$timestamp';

  // URL del Data Bucket para obtener las fotos
  static String get bucketUrl =>
      'https://api.thinger.io/v2/users/$THINGER_USER/buckets/$BUCKET_ID/data?items=10&sort=desc';

  static Map<String, String> get headers => {
    'Authorization': 'Bearer $ACCESS_TOKEN',
    'Content-Type': 'application/json',
  };

  static Map<String, String> get cameraHeaders => {
    'Authorization': 'Bearer $CAMERA_TOKEN',
  };

  static Map<String, String> get bucketHeaders => {
    'Authorization': 'Bearer $THINGER_TOKEN',
    'Content-Type': 'application/json',
  };
}

// ============================================================================
// MODELO DE DATOS
// ============================================================================
class SensorData {
  final double humedadPerro;
  final double humedadGato;
  final int nivelLuz;
  final bool mascotaDetectada;
  final bool motorActivo;
  final bool alertaHumedad;

  SensorData({
    this.humedadPerro = 0.0,
    this.humedadGato = 0.0,
    this.nivelLuz = 0,
    this.mascotaDetectada = false,
    this.motorActivo = false,
    this.alertaHumedad = false,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    // El JSON puede venir dentro de una clave "out"
    final data = json['out'] ?? json;

    return SensorData(
      humedadPerro: (data['humedad_perro'] ?? 0).toDouble(),
      humedadGato: (data['humedad_gato'] ?? 0).toDouble(),
      nivelLuz: (data['nivel_luz'] ?? 0).toInt(),
      mascotaDetectada: data['mascota_detectada'] ?? false,
      motorActivo: data['motor_activo'] ?? false,
      alertaHumedad: data['alerta_humedad'] ?? false,
    );
  }
}

// ============================================================================
// MODELO DE FOTOS DEL BUCKET
// ============================================================================
class FotoMascota {
  final DateTime fecha;
  final String animal;
  final int confianza;
  final String imagenBase64;

  FotoMascota({
    required this.fecha,
    required this.animal,
    required this.confianza,
    required this.imagenBase64,
  });

  factory FotoMascota.fromJson(Map<String, dynamic> json) {
    
    final data = json['val'] ?? json;
    
    return FotoMascota(
      fecha: DateTime.fromMillisecondsSinceEpoch(json['ts'] ?? 0),
      animal: data['animal']?.toString() ?? 'desconocido',
      confianza: (data['confianza'] ?? 0).toInt(),
      imagenBase64: data['imagen']?.toString() ?? '',
    );
  }
}

// ============================================================================
// MAIN
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const SmartFeederApp());
}

class SmartFeederApp extends StatelessWidget {
  const SmartFeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dispensador de Comida - Jean Cardoso, Santiago Pila, Solange Ramos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.light(
          primary: Colors.indigo,
          secondary: Colors.teal,
          surface: Colors.white,
          error: Colors.red.shade400,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: false,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

// ============================================================================
// PANTALLA PRINCIPAL - DASHBOARD
// ============================================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  SensorData _sensorData = SensorData();
  bool _isOnline = false;
  bool _isLoadingPerro = false;
  bool _isLoadingGato = false;
  Timer? _dataTimer;
  Timer? _cameraTimer;
  int _cameraTimestamp = DateTime.now().millisecondsSinceEpoch;
  late AnimationController _gearAnimationController;

  // Lista de fotos del bucket
  List<FotoMascota> _fotos = [];
  bool _isLoadingFotos = false;

  // Control de notificaciones (para no repetir)
  bool _notifiedPocaLuz = false;
  bool _notifiedHumedad = false;
  bool _notifiedMascota = false;
  String _lastFotoId = '';  // Para detectar nuevas fotos
  Timer? _fotosTimer;  // Timer para verificar nuevas fotos

  @override
  void initState() {
    super.initState();
    _gearAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Iniciar timer para leer datos cada 2 segundos
    _fetchData();
    _dataTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchData(),
    );

    // Timer para actualizar la cámara cada 3 segundos
    _cameraTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() {
        _cameraTimestamp = DateTime.now().millisecondsSinceEpoch;
      });
    });

    // Cargar fotos del bucket al inicio y cada 15 segundos
    _fetchFotos();
    _fotosTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchFotos(),
    );
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    _cameraTimer?.cancel();
    _fotosTimer?.cancel();
    _gearAnimationController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LECTURA DE DATOS (GET)
  // ---------------------------------------------------------------------------
  Future<void> _fetchData() async {
    try {
      final response = await http
          .get(Uri.parse(ThingerConfig.readUrl), headers: ThingerConfig.headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final newData = SensorData.fromJson(jsonData);
        
        // Verificar alertas para notificaciones
        _checkAlerts(newData);
        
        setState(() {
          _sensorData = newData;
          _isOnline = true;
        });
      } else {
        setState(() => _isOnline = false);
      }
    } catch (e) {
      setState(() => _isOnline = false);
      debugPrint('Error al obtener datos: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // VERIFICAR ALERTAS Y ENVIAR NOTIFICACIONES
  // ---------------------------------------------------------------------------
  void _checkAlerts(SensorData newData) {
    // Alerta de poca luz (menos de 100 lux)
    if (newData.nivelLuz < 100 && !_notifiedPocaLuz) {
      NotificationService.notifyPocaLuz();
      _notifiedPocaLuz = true;
    } else if (newData.nivelLuz >= 100) {
      _notifiedPocaLuz = false;  // Resetear cuando hay luz
    }

    // Alerta de humedad alta (80% o más en cualquier dispensador)
    bool humedadAlta = newData.humedadPerro >= 80 || newData.humedadGato >= 80;
    if (humedadAlta && !_notifiedHumedad) {
      NotificationService.notifyAlertaHumedad();
      _notifiedHumedad = true;
    } else if (!humedadAlta) {
      _notifiedHumedad = false;  // Resetear cuando baja la humedad
    }

    // Alerta de mascota detectada
    if (newData.mascotaDetectada && !_notifiedMascota) {
      // Se mostrará cuando llegue la foto al bucket con el tipo de animal
      _notifiedMascota = true;
    } else if (!newData.mascotaDetectada) {
      _notifiedMascota = false;  // Resetear cuando no hay mascota
    }
  }

  // ---------------------------------------------------------------------------
  // LECTURA DE FOTOS DEL BUCKET (GET)
  // ---------------------------------------------------------------------------
  Future<void> _fetchFotos() async {
    setState(() => _isLoadingFotos = true);

    try {
      final response = await http
          .get(
            Uri.parse(ThingerConfig.bucketUrl),
            headers: ThingerConfig.bucketHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        
        // El bucket puede devolver los datos en diferentes formatos:
        // 1. Array directo: [{...}, {...}]
        // 2. Objeto con "value": {"value": [{...}], "Count": n}
        List<dynamic> jsonData;
        if (responseData is List) {
          jsonData = responseData;
        } else if (responseData is Map && responseData['value'] != null) {
          jsonData = responseData['value'] as List<dynamic>;
        } else {
          jsonData = [];
        }
        
        // Convertir a lista de FotoMascota
        final newFotos = jsonData.map((item) => FotoMascota.fromJson(item)).toList();
        
        // Verificar si hay una nueva foto y notificar
        if (newFotos.isNotEmpty) {
          final newestFotoId = '${newFotos.first.fecha}_${newFotos.first.animal}';
          if (_lastFotoId.isNotEmpty && newestFotoId != _lastFotoId) {
            // Nueva foto detectada - enviar notificación
            final foto = newFotos.first;
            if (foto.animal != 'ninguno') {
              NotificationService.notifyMascotaDetectada(
                foto.animal,
                foto.confianza.toDouble(),
              );
            }
          }
          _lastFotoId = newestFotoId;
        }
        
        setState(() {
          _fotos = newFotos;
          _isLoadingFotos = false;
        });
      } else {
        setState(() => _isLoadingFotos = false);
        debugPrint('Error bucket: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoadingFotos = false);
      debugPrint('Error al obtener fotos: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ENVÍO DE COMANDOS (POST) - Dispensa comida
  // ---------------------------------------------------------------------------
  Future<void> _sendCommand(String accion) async {
    setState(() {
      if (accion == 'perro') {
        _isLoadingPerro = true;
      } else {
        _isLoadingGato = true;
      }
    });

    try {
      // Enviar comando al ESP32 via Thinger.io
      // NOTA: El ESP32 tarda ~5 segundos en completar (apertura + dosificación + cierre)
      // Usamos timeout corto porque Thinger responde rápido, el ESP32 procesa después
      final response = await http
          .post(
            Uri.parse(ThingerConfig.writeUrl),
            headers: ThingerConfig.headers,
            body: json.encode({'in': accion}),
          )
          .timeout(const Duration(seconds: 5)); // Thinger responde rápido

      if (response.statusCode == 200) {
        _showSnackBar('🍽️ Dispensando $accion... (espera ~5s)', Colors.green);
        // Notificación de comida dispensada
        NotificationService.notifyComidaDispensada(accion);
      } else {
        _showSnackBar('Error: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      // Timeout de Thinger (raro) - el motor puede estar funcionando igual
      _showSnackBar('Comando enviado (verificar motor)', Colors.orange);
      debugPrint('Error al enviar comando: $e');
    } finally {
      setState(() {
        _isLoadingPerro = false;
        _isLoadingGato = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta Hero de Estado
              _buildHeroStatusCard(),
              const SizedBox(height: 20),

              // Tarjetas de Humedad
              _buildSectionTitle('Sensores de Humedad'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildHumidityCard(
                      'Perro',
                      _sensorData.humedadPerro,
                      Icons.pets,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHumidityCard(
                      'Gato',
                      _sensorData.humedadGato,
                      Icons.emoji_nature,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tarjeta de Luz
              _buildSectionTitle('Sensor de Luz'),
              const SizedBox(height: 12),
              _buildLightCard(),
              const SizedBox(height: 24),

              // Galería de Fotos del Bucket
              _buildSectionTitle('Galería de Detecciones'),
              const SizedBox(height: 12),
              _buildPhotoGallery(),
              const SizedBox(height: 24),

              // Botones de Control Manual
              _buildSectionTitle('Control Manual'),
              const SizedBox(height: 12),
              _buildControlButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISOR DE CÁMARA IoT
  // ---------------------------------------------------------------------------
  Widget _buildCameraView() {
    return Card(
      elevation: 4,
      shadowColor: Colors.indigo.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header de la tarjeta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.videocam, color: Colors.indigo.shade600, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Cámara en Vivo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contenedor de la imagen
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: SizedBox(
              height: 250,
              child: Image.network(
                ThingerConfig.cameraUrl(_cameraTimestamp),
                headers: ThingerConfig.cameraHeaders,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.indigo,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Cargando imagen...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Cámara no disponible',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verifica la conexión del dispositivo',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Dispensador de Comida',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            'Jean Cardoso, Santiago Pila, Solange Ramos',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      toolbarHeight: 65,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isOnline ? Colors.green.shade600 : Colors.red.shade400,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TARJETA HERO DE ESTADO
  // ---------------------------------------------------------------------------
  Widget _buildHeroStatusCard() {
    Color cardColor;
    Color iconBgColor;
    String statusText;
    Widget? animatedIcon;

    if (_sensorData.motorActivo) {
      cardColor = Colors.amber.shade700;
      iconBgColor = Colors.amber.shade100;
      statusText = 'DISPENSANDO...';
      animatedIcon = RotationTransition(
        turns: _gearAnimationController,
        child: Icon(Icons.settings, size: 60, color: Colors.amber.shade700),
      );
    } else if (_sensorData.mascotaDetectada) {
      cardColor = Colors.teal.shade600;
      iconBgColor = Colors.teal.shade50;
      statusText = 'MASCOTA DETECTADA';
      animatedIcon = Icon(Icons.pets, size: 60, color: Colors.teal.shade600);
    } else {
      cardColor = Colors.blueGrey;
      iconBgColor = Colors.blueGrey.shade50;
      statusText = 'Esperando...';
      animatedIcon = Icon(
        Icons.hourglass_empty,
        size: 60,
        color: Colors.blueGrey,
      );
    }

    return Card(
      elevation: 6,
      shadowColor: cardColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, cardColor.withOpacity(0.08)],
          ),
          border: Border.all(color: cardColor.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: animatedIcon,
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cardColor,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estado del Sistema',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TÍTULO DE SECCIÓN
  // ---------------------------------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TARJETA DE HUMEDAD
  // ---------------------------------------------------------------------------
  Widget _buildHumidityCard(
    String label,
    double humidity,
    IconData icon,
    Color accentColor,
  ) {
    final bool isAlert = humidity > 70;
    final Color cardColor = isAlert ? Colors.red.shade400 : accentColor;
    final Color bgColor = isAlert
        ? Colors.red.shade50
        : accentColor.withOpacity(0.08);

    return Card(
      elevation: 4,
      shadowColor: cardColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAlert ? Colors.red.shade300 : Colors.transparent,
          width: isAlert ? 2 : 0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColor, Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cardColor, size: 24),
                ),
                if (isAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ALERTA',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${humidity.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: cardColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Humedad $label',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            // Barra de progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: humidity / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(cardColor),
                minHeight: 6,
              ),
            ),
            if (isAlert) ...[
              const SizedBox(height: 8),
              Text(
                'ALERTA HUMEDAD',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade500,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TARJETA DE LUZ
  // ---------------------------------------------------------------------------
  Widget _buildLightCard() {
    final bool isLowLight = _sensorData.nivelLuz < 300;
    final IconData lightIcon = isLowLight
        ? Icons.nightlight_round
        : Icons.wb_sunny;
    final Color lightColor = isLowLight ? Colors.indigo : Colors.amber.shade700;
    final Color bgColor = isLowLight
        ? Colors.indigo.shade50
        : Colors.amber.shade50;

    return Card(
      elevation: 4,
      shadowColor: lightColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [bgColor, Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightColor.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: lightColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(lightIcon, size: 40, color: lightColor),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_sensorData.nivelLuz} Lux',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: lightColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nivel de Luz',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isLowLight)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: Colors.indigo.shade600,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Poca Luz',
                      style: TextStyle(
                        color: Colors.indigo.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GALERÍA DE FOTOS DEL BUCKET
  // ---------------------------------------------------------------------------
  Widget _buildPhotoGallery() {
    if (_isLoadingFotos) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: 200,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.indigo),
                SizedBox(height: 12),
                Text('Cargando fotos...'),
              ],
            ),
          ),
        ),
      );
    }

    if (_fotos.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: 150,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 50,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay fotos disponibles',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _fetchFotos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.indigo.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library,
                  color: Colors.teal.shade600,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Fotos Detectadas (${_fotos.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _fetchFotos,
                  icon: Icon(Icons.refresh, color: Colors.teal.shade600),
                  tooltip: 'Actualizar fotos',
                ),
              ],
            ),
          ),
          // Lista horizontal de fotos
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: _fotos.length,
              itemBuilder: (context, index) {
                final foto = _fotos[index];
                return _buildPhotoCard(foto);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(FotoMascota foto) {
    // Decodificar imagen Base64
    Widget imageWidget;
    
    // Debug: verificar contenido de la imagen
    debugPrint('=== FOTO DEBUG ===');
    debugPrint('Animal: ${foto.animal}');
    debugPrint('Confianza: ${foto.confianza}');
    debugPrint('Imagen length: ${foto.imagenBase64.length}');
    debugPrint('Imagen preview: ${foto.imagenBase64.length > 50 ? foto.imagenBase64.substring(0, 50) : foto.imagenBase64}...');
    
    try {
      if (foto.imagenBase64.isEmpty) {
        throw Exception('Imagen vacía');
      }
      
      // Limpiar el Base64 (remover posibles prefijos de data URI)
      String cleanBase64 = foto.imagenBase64;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      
      final bytes = base64Decode(cleanBase64);
      imageWidget = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error al mostrar imagen: $error');
          return Container(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image,
              size: 50,
              color: Colors.grey.shade400,
            ),
          );
        },
      );
    } catch (e) {
      imageWidget = Container(
        color: Colors.grey.shade200,
        child: Icon(Icons.broken_image, size: 50, color: Colors.grey.shade400),
      );
    }

    // Color según el animal detectado
    Color animalColor;
    IconData animalIcon;
    switch (foto.animal.toLowerCase()) {
      case 'perro':
        animalColor = Colors.blue;
        animalIcon = Icons.pets;
        break;
      case 'gato':
        animalColor = Colors.orange;
        animalIcon = Icons.emoji_nature;
        break;
      default:
        animalColor = Colors.grey;
        animalIcon = Icons.help_outline;
    }

    return GestureDetector(
      onTap: () => _showPhotoDialog(foto, imageWidget),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: SizedBox(height: 120, child: imageWidget),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(animalIcon, size: 16, color: animalColor),
                      const SizedBox(width: 4),
                      Text(
                        foto.animal.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: animalColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${foto.fecha.day}/${foto.fecha.month}/${foto.fecha.year}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    '${foto.fecha.hour.toString().padLeft(2, '0')}:${foto.fecha.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoDialog(FotoMascota foto, Widget imageWidget) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: AspectRatio(aspectRatio: 4 / 3, child: imageWidget),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Animal: ${foto.animal.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confianza: ${foto.confianza}%',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fecha: ${foto.fecha.day}/${foto.fecha.month}/${foto.fecha.year} ${foto.fecha.hour.toString().padLeft(2, '0')}:${foto.fecha.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTONES DE CONTROL
  // ---------------------------------------------------------------------------
  Widget _buildControlButtons() {
    return Column(
      children: [
        // Botón Dispensar Perro
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoadingPerro ? null : () => _sendCommand('perro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.indigo.shade200,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Colors.indigo.withOpacity(0.3),
            ),
            child: _isLoadingPerro
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Dispensar Perro',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Botón Dispensar Gato
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoadingGato ? null : () => _sendCommand('gato'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.teal.shade200,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Colors.teal.withOpacity(0.3),
            ),
            child: _isLoadingGato
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_nature, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Dispensar Gato',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
