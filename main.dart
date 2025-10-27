import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
const String weatherApiKey = "71ef82688995a6cac6df39bd85764839";
Future<Map<String, dynamic>> fetchCurrentWeather(String city) async {
  final Uri url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$weatherApiKey&units=metric&lang=vi");
  final http.Response response = await http.get(url);
  if (response.statusCode == 200) {
    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  } else {
    throw Exception(" Không tìm thấy thành phố hoặc API lỗi!");
  }
}
Future<Map<String, dynamic>> fetchAirQuality(double lat, double lon) async {
  final Uri url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$weatherApiKey");
  final http.Response response = await http.get(url);
  if (response.statusCode == 200) {
    final Map<String, dynamic> data =
    jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  } else {
    throw Exception(" Không lấy được chất lượng không khí!");
  }
}
Future<(Map<String, dynamic>, Map<String, dynamic>)> loadWeatherData(
    String city) async {
  try {
    final Map<String, dynamic> weather =
    await fetchCurrentWeather(city).timeout(
      const Duration(seconds: 5),
    );
    final double lat = weather["coord"]["lat"] as double;
    final double lon = weather["coord"]["lon"] as double;
    final results = await Future.wait([
      fetchCurrentWeather(city),
      fetchAirQuality(lat, lon),
    ]);
    return (results[0], results[1]);
  } on SocketException {
    throw Exception(" Không có kết nối mạng!");
  } on TimeoutException {
    throw Exception(" Tải dữ liệu quá lâu vui lòng thử lại!");
  } catch (e) {
    throw Exception(" Đã xảy ra lỗi không xác định: $e");
  }
}
void main() {
  runApp(const WeatherAppMini());
}
class WeatherAppMini extends StatelessWidget {
  const WeatherAppMini({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherScreen(),
    );
  }
}
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}
class _WeatherScreenState extends State<WeatherScreen> {
  String city = "danang";
  late Future<(Map<String, dynamic>, Map<String, dynamic>)> futureWeather;
  final TextEditingController controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    controller.text = city;
    futureWeather = loadWeatherData(city);
  }
  void searchCity() {
    setState(() {
      city = controller.text;
      futureWeather = loadWeatherData(city);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(" Weather App")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Nhập thành phố",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: searchCity,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<(Map<String, dynamic>, Map<String, dynamic>)>(
                future: futureWeather,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final String errorMessage =
                    snapshot.error.toString();
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(errorMessage,
                              textAlign: TextAlign.center,
                              style:
                              const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: searchCity,
                            child: const Text("Thử lại"),
                          )
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasData) {
                    final Map<String, dynamic> weather =
                        snapshot.data!.$1;
                    final Map<String, dynamic> air =
                        snapshot.data!.$2;
                    return WeatherCard(
                      weather: weather,
                      air: air,
                      refresh: searchCity,
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class WeatherCard extends StatelessWidget {
  final Map<String, dynamic> weather;
  final Map<String, dynamic> air;
  final VoidCallback refresh;

  const WeatherCard({
    super.key,
    required this.weather,
    required this.air,
    required this.refresh,
  });
  String getAqiDescription(int aqi) {
    switch (aqi) {
      case 1: return "Tốt";
      case 2: return "Trung bình";
      case 3: return "Kém";
      case 4: return "Xấu";
      case 5: return "Rất xấu";
      default: return "Không xác định";
    }
  }
  IconData getWeatherIcon(double rain) {
    if (rain > 0.0) {
      return Icons.cloudy_snowing;
    }
    return Icons.wb_sunny_rounded;
  }
  Color getWeatherColor(double rain) {
    if (rain > 0.0) {
      return Colors.blue;
    }
    return Colors.orange;
  }
  @override
  Widget build(BuildContext context) {
    final String cityName = weather["name"];
    final double temp = (weather["main"]["temp"] as num).toDouble();
    final int humidity = weather["main"]["humidity"] as int;
    final double wind = (weather["wind"]["speed"] as num).toDouble();
    final String description = weather["weather"][0]["description"];
    final int airQuality = air["list"][0]["main"]["aqi"] as int;
    final double rain = weather["rain"]?["1h"] ?? 0.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined, size: 22),
              const SizedBox(width: 6),
              Text(cityName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "${temp.round()}°C",
            style: const TextStyle(
                fontSize: 80, fontWeight: FontWeight.w700, color: Colors.red),
          ),
          Icon(getWeatherIcon(rain), size: 80, color: getWeatherColor(rain)),
          Text(description,
              style: const TextStyle(fontSize: 20, color: Colors.grey)),

          const SizedBox(height: 30),
          Wrap(
            runSpacing: 18,
            spacing: 18,
            alignment: WrapAlignment.center,
            children: [
              infoCard(Icons.water_drop_rounded, "$humidity%", "Độ ẩm"),
              infoCard(Icons.cloudy_snowing, "$rain mm", "Lượng mưa"),
              infoCard(Icons.air_rounded, "${wind.toStringAsFixed(1)} km/h", "Gió"),
              infoCard(Icons.speed_rounded, "$airQuality • ${getAqiDescription(airQuality)}", "AQI"),
            ],
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            label: const Text("Làm mới"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  Widget infoCard(IconData icon, String value, String title) {
    return Container(
      width:  170,
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Icon(icon, size: 20, color: Colors.lightBlueAccent),
            const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(color: Colors.black , fontSize: 20))
          ]),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

