import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Widget h1(String text) => pw.Text(
  text,
  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
);

pw.Widget table(List<String> headers, List<List<String>> rows) {
  return pw.Table.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
    cellStyle: const pw.TextStyle(fontSize: 10),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    cellAlignment: pw.Alignment.centerLeft,
  );
}
