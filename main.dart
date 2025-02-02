import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const LibraryManagementApp());
}

class LibraryManagementApp extends StatelessWidget {
  const LibraryManagementApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Library Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
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
  Timer? dataUpdateTimer;
  Map<String, dynamic> currentData = {};
  List<Map<String, dynamic>> historicalData = [];

  @override
  void initState() {
    super.initState();
    startDataUpdates();
  }

  void startDataUpdates() {
    dataUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchData();
    });
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.thingspeak.com/channels/$channelId/feeds/last.json?api_key=$readApiKey'
      ));

      if (response.statusCode == 200) {
        setState(() {
          currentData = json.decode(response.body);
          historicalData.add(currentData);
          if (historicalData.length > 30) {
            historicalData.removeAt(0);
          }
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library Management'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Real-time'),
              Tab(icon: Icon(Icons.history), text: 'Historical'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRealTimeTab(),
            _buildHistoricalTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMetricCard('Temperature', '${currentData['field2']}°C', Icons.thermostat),
          _buildMetricCard('Humidity', '${currentData['field3']}%', Icons.water_drop),
          _buildMetricCard('People Count', currentData['field1']?.toString() ?? '0', Icons.people),
          _buildMetricCard('Light Level', currentData['field4']?.toString() ?? '0', Icons.light_mode),
          _buildMetricCard('Smoke Level', currentData['field5']?.toString() ?? '0', Icons.smoke_free),
        ],
      ),
    );
  }

  Widget _buildHistoricalTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildChart('Temperature (°C)', 'field2', Colors.red),
          _buildChart('Humidity (%)', 'field3', Colors.blue),
          _buildChart('People Count', 'field1', Colors.green),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(String title, String field, Color color) {
    return SizedBox(
      height: 200,
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    dataUpdateTimer?.cancel();
    super.dispose();
  }
}
