# 🐾 Smart Feeder - Sistema IoT de Dispensador Inteligente para Mascotas

## 📋 Descripción General

Sistema de Internet de las Cosas (IoT) que permite monitorear y controlar un dispensador de comida para mascotas de forma remota. Utiliza visión artificial para detectar perros y gatos, dispensando automáticamente la porción correcta de alimento.

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SMART FEEDER - IoT                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────┐   │
│   │  ESP32-CAM   │     │   ESP32      │     │   Computadora/RPi        │   │
│   │  (Cámara)    │     │   (Motor)    │     │   (Visión Artificial)    │   │
│   └──────┬───────┘     └──────┬───────┘     └────────────┬─────────────┘   │
│          │                    │                          │                  │
│          │    Red WiFi Local  │                          │                  │
│          └────────────────────┼──────────────────────────┘                  │
│                               │                                             │
│                    ┌──────────▼──────────┐                                  │
│                    │    Thinger.io       │                                  │
│                    │   (Plataforma IoT)  │                                  │
│                    │   - API REST        │                                  │
│                    │   - Data Buckets    │                                  │
│                    │   - Dispositivos    │                                  │
│                    └──────────┬──────────┘                                  │
│                               │                                             │
│                    ┌──────────▼──────────┐                                  │
│                    │   App Móvil Flutter │                                  │
│                    │   - Dashboard       │                                  │
│                    │   - Control Manual  │                                  │
│                    │   - Notificaciones  │                                  │
│                    └─────────────────────┘                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Componentes del Sistema

### 1. Hardware

| Componente | Función | Descripción |
|------------|---------|-------------|
| **ESP32-CAM** | Captura de imágenes | Cámara WiFi que transmite imágenes para detección |
| **ESP32** | Control de motor | Microcontrolador que maneja el servo/motor DC |
| **Motor DC/Servo** | Dispensar comida | Abre/cierra la compuerta del dispensador |
| **Sensor de Humedad** | Monitoreo ambiental | Detecta humedad en contenedores (perro/gato) |
| **Sensor LDR** | Nivel de luz | Mide iluminación ambiente |
| **OLED Display** | Visualización local | Muestra estado y detecciones |

### 2. Software

| Componente | Tecnología | Función |
|------------|------------|---------|
| **App Móvil** | Flutter/Dart | Interfaz de usuario y control remoto |
| **Script IA** | Python + TensorFlow | Detección de mascotas con ResNet50 |
| **Plataforma IoT** | Thinger.io | Backend, API REST, almacenamiento |

---

## 📱 Aplicación Móvil Flutter

### Características Implementadas

#### ✅ Dashboard Principal
- Estado de conexión (Online/Offline)
- Indicador visual de actividad del sistema
- Actualización automática cada 2 segundos

#### ✅ Sensores de Humedad
- Humedad contenedor Perro (%)
- Humedad contenedor Gato (%)
- Alertas visuales cuando supera **80%** de humedad
- Notificación automática al detectar humedad alta

#### ✅ Sensor de Luz
- Nivel de luz en Lux
- Indicador de "Poca Luz" / "Buena Luz"
- Notificación automática cuando hay poca luz

#### ✅ Galería de Detecciones
- Fotos almacenadas en Data Bucket
- Tipo de animal detectado (Perro/Gato)
- Porcentaje de confianza de la IA
- Fecha y hora de captura
- Actualización cada 15 segundos

#### ✅ Control Manual
- Botón "Dispensar Perro"
- Botón "Dispensar Gato"
- Feedback visual durante operación

#### ✅ Sistema de Notificaciones
- 🐕 Mascota detectada (perro/gato)
- 🍽️ Comida dispensada exitosamente
- 💡 Poca luz - Activando iluminación
- ⚠️ Alerta de humedad alta

---

## 🌐 API Thinger.io

### Configuración de Credenciales

```dart
class ThingerConfig {
  static const String THINGER_USER = 'jeanpoll';
  static const String DEVICE_ID = 'dispensador01';
  static const String CAMERA_DEVICE_ID = 'camara01';
  static const String BUCKET_ID = 'fotos_mascotas';
  
  // Tokens de autenticación
  static const String ACCESS_TOKEN = '...';      // Token dispositivo
  static const String CAMERA_TOKEN = '...';      // Token cámara
  static const String THINGER_TOKEN = '...';     // Token proyecto (bucket)
}
```

### Endpoints Utilizados

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/devices/{id}/datos_generales` | GET | Leer sensores |
| `/devices/{id}/control_motor` | POST | Enviar comando motor |
| `/buckets/{id}/data` | GET | Obtener fotos guardadas |

### Estructura de Datos

#### Lectura de Sensores (GET datos_generales)
```json
{
  "out": {
    "humedad_perro": 45.5,
    "humedad_gato": 38.2,
    "nivel_luz": 250,
    "mascota_detectada": true,
    "motor_activo": false,
    "alerta_humedad": false
  }
}
```

#### Control de Motor (POST control_motor)
```json
{
  "in": "perro"
}
```
Valores: `"perro"`, `"gato"`, `"stop"`

#### Fotos del Bucket (GET bucket/data)
```json
{
  "value": [
    {
      "animal": "perro",
      "confianza": 47.59,
      "imagen": "/9j/4AAQSkZ...",  // Base64
      "ts": 1769555291851
    }
  ],
  "Count": 1
}
```

---

## 🐍 Script de Visión Artificial (Python)

### Dependencias
```bash
pip install requests opencv-python numpy tensorflow
```

### Funcionamiento

1. **Captura**: Obtiene imagen de ESP32-CAM vía HTTP
2. **Detección**: Procesa con ResNet50 (ImageNet)
3. **Clasificación**: Busca palabras clave de perros/gatos
4. **Acción**: Si detecta mascota:
   - Envía comando al motor
   - Sube foto al bucket de Thinger.io
5. **Loop**: Repite cada frame

### Palabras Clave de Detección

**Perros**: dog, terrier, retriever, shepherd, hound, spaniel, bulldog, poodle, chihuahua, beagle, rottweiler, boxer, pug, collie, husky, corgi, dachshund...

**Gatos**: cat, tabby, tiger_cat, egyptian_cat, siamese, persian, maine_coon, bengal, british_shorthair...

### Umbrales de Confianza (Visión Artificial)
- Perro: 15%
- Gato: 10% (más sensible)

### Umbrales de Sensores (App Móvil)
| Sensor | Umbral | Acción |
|--------|--------|--------|
| Humedad | ≥ 80% | Notificación de alerta |
| Luz | < 100 lux | Notificación de poca luz |

### Tiempos de Operación
| Operación | Duración |
|-----------|----------|
| Dispensación de comida | ~5 segundos |
| Actualización de sensores | Cada 2 segundos |
| Actualización de fotos | Cada 15 segundos |
| Refresco de cámara | Cada 3 segundos |

---

## 📂 Estructura del Proyecto Flutter

```
lib/
└── main.dart
    ├── NotificationService      # Servicio de notificaciones locales
    ├── ThingerConfig           # Credenciales y URLs de API
    ├── SensorData              # Modelo de datos de sensores
    ├── FotoMascota             # Modelo de fotos del bucket
    ├── SmartFeederApp          # Widget principal
    └── DashboardScreen         # Pantalla de dashboard
        ├── _fetchData()        # Lectura de sensores (cada 2s)
        ├── _fetchFotos()       # Lectura de bucket (cada 15s)
        ├── _sendCommand()      # Envío de comandos al motor
        ├── _checkAlerts()      # Verificación de alertas
        ├── _buildHeroStatusCard()
        ├── _buildHumidityCard()
        ├── _buildLightCard()
        ├── _buildPhotoGallery()
        └── _buildControlButtons()
```

---

## 🔔 Sistema de Notificaciones

### Configuración Android

Se requiere habilitar "desugaring" en `android/app/build.gradle.kts`:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

### Tipos de Notificaciones

| ID | Evento | Título | Descripción |
|----|--------|--------|-------------|
| 1 | Mascota detectada | "🐕 ¡PERRO Detectado!" | Confianza % |
| 2 | Comida dispensada | "🐕 Comida Dispensada" | Para perro/gato |
| 3 | Poca luz | "💡 Prendiendo Iluminación" | Activando focos |
| 4 | Humedad alta | "⚠️ Alerta de Humedad" | Dispensador húmedo |

### Lógica Anti-Repetición

Las notificaciones usan flags booleanos para evitar spam:
- `_notifiedPocaLuz`: Se resetea cuando luz >= 100 lux
- `_notifiedHumedad`: Se activa cuando humedad >= 80%, se resetea cuando baja
- `_lastFotoId`: Compara ID de última foto para detectar nuevas

---

## 🚀 Compilación y Despliegue

### Requisitos
- Flutter SDK 3.10+
- Android SDK 34
- Java 17

### Comandos

```bash
# Instalar dependencias
flutter pub get

# Compilar APK
flutter build apk

# APK generado en:
# build/app/outputs/flutter-apk/app-release.apk
```

### Tamaño del APK
- Release: ~43.5 MB

---

## 📊 Flujo de Datos

```
1. ESP32-CAM captura imagen
         ↓
2. Python descarga imagen via HTTP
         ↓
3. ResNet50 procesa y detecta
         ↓
4. Si detecta perro/gato:
   ├── Envía comando a ESP32 (motor local)
   ├── Notifica a Thinger.io (nube)
   └── Sube foto al bucket
         ↓
5. App Flutter lee datos cada 2s
         ↓
6. Si hay cambios significativos:
   └── Envía notificación local al usuario
```

---

## 🔐 Seguridad

- **Tokens JWT**: Cada dispositivo tiene su propio token
- **HTTPS**: Comunicación cifrada con Thinger.io
- **Permisos Android**: Solo se solicitan los necesarios
  - Internet
  - Notificaciones

---

## 🐛 Solución de Problemas

| Problema | Causa | Solución |
|----------|-------|----------|
| "Offline" en app | ESP32 desconectado | Verificar WiFi del ESP32 |
| Fotos no cargan | Token incorrecto | Usar THINGER_TOKEN para bucket |
| Motor no responde | Timeout | Aumentar timeout a 10s |
| "ninguno" en bucket | Script Python | Usar versión corregida V3.1 |
| Error 401 | Token expirado | Generar nuevo token en Thinger |

---

## 👨‍💻 Autores

**Proyecto IoT - 2025-B**

- Jean Cardoso
- Santiago Pila
- Solange Ramos

Desarrollado con:
- Flutter & Dart
- Python & TensorFlow
- ESP32 & Arduino
- Thinger.io Platform

---

## 📄 Licencia

Proyecto académico - Universidad 2025-B
