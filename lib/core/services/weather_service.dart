import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherInfo {
  final String weather;
  final bool isNight;
  final String season;

  WeatherInfo({
    required this.weather,
    required this.isNight,
    required this.season,
  });
}

class WeatherService {
  static const _apiKey = '82e9fd81b84ce6a84016c49b18490b47'; // 🔑 본인 키로 교체
  static const _apiUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // 위치 권한 및 현재 위치 가져오기
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  }

  // 날씨 정보 + 일출/일몰 기반 밤/낮 판별
  static Future<WeatherInfo> fetchWeatherInfo() async {
    final position = await getCurrentPosition();
    final url = '$_apiUrl?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('날씨 정보를 가져오는 데 실패했습니다.');
    }

    final data = json.decode(response.body);

    // 날씨
    final weather = data['weather'][0]['main'].toLowerCase(); // ex: clear, clouds, rain, snow

    // 한국 시간 기준 현재 시각
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));

    // 일출/일몰 (UTC → KST)
    final sunrise = DateTime.fromMillisecondsSinceEpoch(data['sys']['sunrise'] * 1000, isUtc: true)
        .add(const Duration(hours: 9));
    final sunset = DateTime.fromMillisecondsSinceEpoch(data['sys']['sunset'] * 1000, isUtc: true)
        .add(const Duration(hours: 9));

    // 밤 여부 판별
    final isNight = now.isBefore(sunrise) || now.isAfter(sunset);

    // 계절 판별
    final season = _getSeason(now.month);

    return WeatherInfo(
      weather: weather,
      isNight: isNight,
      season: season,
    );
  }

  // 계절 계산
  static String _getSeason(int month) {
    if ([12, 1, 2].contains(month)) return 'winter';
    if ([3, 4, 5].contains(month)) return 'spring';
    if ([6, 7, 8].contains(month)) return 'summer';
    return 'autumn';
  }
}
