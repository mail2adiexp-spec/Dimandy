import 'dart:io';

void main() async {
  final file = File('lib/screens/admin_panel_screen.dart');
  final lines = await file.readAsLines();
  
  // Lines to delete (1-based): 5485 to 5738
  // Indices (0-based): 5484 to 5737
  final start = 5484;
  final end = 5738; // Exclusive in removeRange
  
  print('Deleting lines ${start + 1} to $end');
  print('First line to delete: ${lines[start]}');
  print('Last line to delete: ${lines[end - 1]}');
  
  lines.removeRange(start, end);
  
  await file.writeAsString(lines.join('\n'));
  print('Successfully deleted orphaned code');
}
