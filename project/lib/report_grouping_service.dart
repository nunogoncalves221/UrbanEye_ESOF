import 'dart:math';
import 'report.dart';
import 'alert.dart';



// groups reports in single "problems"

// two reports are grouped when they share the same category and are within *proximity_rad* from each other (in this case 80m)

class ReportGroupingService {
  final double proximity_rad;
  ReportGroupingService({this.proximity_rad=80});

  List<Alert> groupReports(List<Report> reports){
    final List<Alert> alerts =[];

    for (final report in reports){
      final matchIndex = alerts.indexWhere(
        (alert) =>
        alert.category == report.category && distanceMeters(alert.latitude, alert.longitude, report.latitude,report.longitude,)<= proximity_rad,
      );
      if (matchIndex != -1){ // existe um alerta e vou adicionar este report a ele
        alerts[matchIndex]= alerts[matchIndex].copyWith(reportCount: alerts[matchIndex].reportCount+1);
      }
      else{ //criar um novo alert
        alerts.add(Alert(
          id: 'alert_${alerts.length +1}',
          category: report.category,
          reportCount:1,
          latitude: report.latitude,
          longitude:report.longitude,
        ));
      }
    }
    return alerts;
  }

    /// Haversine formula – returns distance in metres between two coordinates.
  double distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }
 
  double _toRad(double deg) => deg * pi / 180;
}


