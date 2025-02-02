import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';  // Added this import for Uint8List
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:intl/intl.dart';

void main() {
  runApp(const LibraryManagementApp());
}

class LibraryManagementApp extends StatelessWidget {
  const LibraryManagementApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Library Management',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4B7BEC),
          secondary: Color(0xFF45AAF2),
          surface: Color(0xFF2C3E50),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF2C3E50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const String channelId = '2794357';
  static const String readApiKey = 'TT4QQST43HP84RGH';
  static const String mqttBroker = 'broker.hivemq.com';
  static const int mqttPort = 1883;
  static const String mqttTopic = 'raspberrypi/video_stream';

  late MqttServerClient mqttClient;
  Uint8List? currentFrame;
  Timer? dataUpdateTimer;
  Map<String, dynamic> currentData = {};
  List<Map<String, dynamic>> historicalData = [];
  bool isConnectedToMqtt = false;

  @override
  void initState() {
    super.initState();
    setupMqttClient();
    startDataUpdates();
  }

  Future<void> setupMqttClient() async {
    mqttClient = MqttServerClient(mqttBroker, 'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
    mqttClient.port = mqttPort;
    mqttClient.keepAlivePeriod = 20;
    mqttClient.autoReconnect = true;

    try {
      await mqttClient.connect();
      mqttClient.subscribe(mqttTopic, MqttQos.atMostOnce);

      mqttClient.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        final MqttPublishMessage message = messages[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);

        try {
          setState(() {
            currentFrame = base64Decode(payload);
            isConnectedToMqtt = true;
          });
        } catch (e) {
          print('Frame decode error: $e');
        }
      });

      mqttClient.onDisconnected = () {
        setState(() {
          isConnectedToMqtt = false;
        });
        Future.delayed(const Duration(seconds: 5), setupMqttClient);
      };

    } catch (e) {
      print('MQTT Connection failed: $e');
      Future.delayed(const Duration(seconds: 5), setupMqttClient);
    }
  }

  void startDataUpdates() {
    // Increase update frequency to 5 seconds
    dataUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchThingSpeakData();
    });
    fetchThingSpeakData();
  }

  Future<void> fetchThingSpeakData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.thingspeak.com/channels/$channelId/feeds/last.json?api_key=$readApiKey'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentData = data;
          historicalData.add(data);
          if (historicalData.length > 50) { // Reduce buffer size to improve performance
            historicalData.removeAt(0);
          }
        });
      }
    } catch (e) {
      print('ThingSpeak fetch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Smart Library Management'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Real-time'),
              Tab(icon: Icon(Icons.history), text: 'Historical'),
              Tab(icon: Icon(Icons.videocam), text: 'Video Feed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRealTimeTab(),
            SingleChildScrollView(child: _buildHistoricalTab()),
            _buildVideoTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _buildMetricCard('Temperature', '${currentData['field2']}°C', Icons.thermostat),
            _buildMetricCard('Humidity', '${currentData['field3']}%', Icons.water_drop),
            _buildMetricCard('People Count', currentData['field1']?.toString() ?? '0', Icons.people),
            _buildMetricCard('Light Level', currentData['field4']?.toString() ?? '0', Icons.light_mode),
            _buildMetricCard('Smoke Level', currentData['field5']?.toString() ?? '0', Icons.smoke_free),
            _buildMetricCard('Sound Level', currentData['field6']?.toString() ?? '0', Icons.volume_up),
            _buildMetricCard('Door Status', currentData['field7'] == '1' ? 'Open' : 'Closed', Icons.meeting_room),
            _buildMetricCard('Fan Status', currentData['field8'] == '1' ? 'ON' : 'OFF', Icons.wind_power),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 160,
      height: 120,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoricalTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildChart('Temperature (°C)', 'field2', Colors.red),
          const SizedBox(height: 8),
          _buildChart('Humidity (%)', 'field3', Colors.blue),
          const SizedBox(height: 8),
          _buildChart('People Count', 'field1', Colors.green),
          const SizedBox(height: 8),
          _buildChart('Light Level', 'field4', Colors.yellow),
          const SizedBox(height: 8),
          _buildChart('Smoke Level', 'field5', Colors.grey),
          const SizedBox(height: 8),
          _buildChart('Sound Level', 'field6', Colors.purple),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: saveHistoricalData,
            icon: const Icon(Icons.save),
            label: const Text('Save Historical Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(String title, String field, Color color) {
    return SizedBox(
      height: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: true),
                    titlesData: FlTitlesData(
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 20,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: 5,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: historicalData.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            double.tryParse(entry.value[field]?.toString() ?? '0') ?? 0,
                          );
                        }).toList(),
                        isCurved: true,
                        color: color,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isConnectedToMqtt)
            const Text('Connecting to video stream...'),
          if (currentFrame == null && isConnectedToMqtt)
            const Text('Waiting for video feed...'),
          if (currentFrame != null)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Image.memory(
                currentFrame!,
                gaplessPlayback: true,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> saveHistoricalData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      List<List<dynamic>> csvData = [
        ['Timestamp', 'Temperature', 'Humidity', 'People Count', 'Light', 'Smoke', 'Sound', 'Door', 'Fan'],
        ...historicalData.map((data) => [
          data['created_at'],
          data['field2'],
          data['field3'],
          data['field1'],
          data['field4'],
          data['field5'],
          data['field6'],
          data['field7'],
          data['field8'],
        ])
      ];

      String csv = const ListToCsvConverter().convert(csvData);
      final csvFile = File('${directory.path}/library_data_$timestamp.csv');
      await csvFile.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data saved successfully!')),
      );
    } catch (e) {
      print('Save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving data')),
      );
    }
  }

  @override
  void dispose() {
    dataUpdateTimer?.cancel();
    mqttClient.disconnect();
    super.dispose();
  }
}
