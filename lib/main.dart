import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// CONFIGURACIÓN THINGER.IO - LLENAR CON TUS CREDENCIALES
// ============================================================================
class ThingerConfig {
  static const String THINGER_USER = 'jeanpoll';
  static const String DEVICE_ID = 'dispensador01';
  static const String ACCESS_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXYiOiJkaXNwZW5zYWRvcjAxIiwiaWF0IjoxNzY5MzExNDYxLCJqdGkiOiI2OTc1OGNlNTI4M2JhMDljNTYwOTY4NzUiLCJzdnIiOiJ1cy1lYXN0LmF3cy50aGluZ2VyLmlvIiwidXNyIjoiamVhbnBvbGwifQ.FiDQ3E7HT2zvkTm06apM12qya7jBs9V330KPpYwTLKU';

  static String get readUrl =>
      'https://api.thinger.io/v2/users/$THINGER_USER/devices/$DEVICE_ID/datos_generales';

  static String get writeUrl =>
      'https://api.thinger.io/v2/users/$THINGER_USER/devices/$DEVICE_ID/control_motor';

  static Map<String, String> get headers => {
        'Authorization': 'Bearer $ACCESS_TOKEN',
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
// MAIN
// ============================================================================
void main() {
  runApp(const SmartFeederApp());
}

class SmartFeederApp extends StatelessWidget {
  const SmartFeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Feeder',
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
  late AnimationController _gearAnimationController;

  @override
  void initState() {
    super.initState();
    _gearAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Iniciar timer para leer datos cada 2 segundos
    _fetchData();
    _dataTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchData());
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    _gearAnimationController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LECTURA DE DATOS (GET)
  // ---------------------------------------------------------------------------
  Future<void> _fetchData() async {
    try {
      final response = await http
          .get(
            Uri.parse(ThingerConfig.readUrl),
            headers: ThingerConfig.headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          _sensorData = SensorData.fromJson(jsonData);
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
  // ENVÍO DE COMANDOS (POST)
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
      final response = await http
          .post(
            Uri.parse(ThingerConfig.writeUrl),
            headers: ThingerConfig.headers,
            body: json.encode({'in': {'accion': accion}}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _showSnackBar('Comando enviado: $accion', Colors.green);
      } else {
        _showSnackBar('Error al enviar comando', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error de conexión', Colors.red);
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
  // APP BAR
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(
            Icons.pets,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 10),
          const Text(
            'Smart Feeder',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ],
      ),
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
        child: Icon(
          Icons.settings,
          size: 60,
          color: Colors.amber.shade700,
        ),
      );
    } else if (_sensorData.mascotaDetectada) {
      cardColor = Colors.teal.shade600;
      iconBgColor = Colors.teal.shade50;
      statusText = 'MASCOTA DETECTADA';
      animatedIcon = Icon(
        Icons.pets,
        size: 60,
        color: Colors.teal.shade600,
      );
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              cardColor.withOpacity(0.08),
            ],
          ),
          border: Border.all(
            color: cardColor.withOpacity(0.3),
            width: 1.5,
          ),
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
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
    final Color bgColor = isAlert ? Colors.red.shade50 : accentColor.withOpacity(0.08);

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
            colors: [
              bgColor,
              Colors.white,
            ],
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
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 14),
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
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
    final IconData lightIcon = isLowLight ? Icons.nightlight_round : Icons.wb_sunny;
    final Color lightColor = isLowLight ? Colors.indigo : Colors.amber.shade700;
    final Color bgColor = isLowLight ? Colors.indigo.shade50 : Colors.amber.shade50;

    return Card(
      elevation: 4,
      shadowColor: lightColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              bgColor,
              Colors.white,
            ],
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
              child: Icon(
                lightIcon,
                size: 40,
                color: lightColor,
              ),
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
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
                  border: Border.all(
                    color: Colors.indigo.shade200,
                  ),
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
