/// โครงสร้างข้อมูลสรุปค่ารอบแบบรายวัน
class DailyTripSummary {
  const DailyTripSummary({
    required this.date,
    required this.totalBaht,
    required this.totalRounds,
    required this.recordCount,
  });

  final DateTime date;
  final int totalBaht;
  final int totalRounds;
  final int recordCount;
}

/// โครงสร้างข้อมูลสรุปค่ารอบตามช่วงเวลา (เช่น รายสัปดาห์ หรือ รายเดือน)
class PeriodSummary {
  const PeriodSummary({
    required this.periodStart,
    required this.totalBaht,
    required this.totalRounds,
    required this.recordCount,
  });

  final DateTime periodStart;
  final int totalBaht;
  final int totalRounds;
  final int recordCount;
}

/// โครงสร้างข้อมูลสรุปสถิติตามระยะทาง
class DistanceStats {
  DistanceStats({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  int count;
  int total;
}
