import 'csv_export_stub.dart' if (dart.library.html) 'csv_export_web.dart' as exporter;

void exportCsv(String csvContent, String filename) {
  exporter.downloadCsvFile(csvContent, filename);
}

