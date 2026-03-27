class Alert{
  final String id;
  final String category;
  final int reportCount;
  final double latitude;
  final double longitude;



  Alert({
    required this.id,
    required this.category,
    required this.reportCount,
    required this.latitude,
    required this.longitude,
  });

  Alert copyWith({ int? reportCount}){
    return Alert(
      id: id,
      category: category,
      reportCount: reportCount ?? this.reportCount,
      latitude: latitude,
      longitude:longitude,
    );  
  }
}