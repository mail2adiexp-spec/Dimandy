import 'dart:io';

void main() async {
  final file = File('lib/screens/admin_panel_screen.dart');
  final lines = await file.readAsLines();
  
  // Find start
  int startIndex = -1;
  int endIndex = -1;
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('Widget _buildProviderServicesTab(String providerId) {')) {
      startIndex = i;
      break;
    }
  }
  
  if (startIndex == -1) {
    print('Could not find _buildProviderServicesTab start');
    return;
  }
  
  // Find end (we know it's around 5733, but let's count braces to be safe-ish or just look for indented closing brace at expected level)
  // Actually, based on previous view_file, line 5733 (1-indexed) is '  }' which closes the method.
  // equivalent to index 5732.
  
  // Let's verify indentation.
  // Start line indentation is `  Widget ...` (2 spaces)
  // We expect the closing brace to be `  }` (2 spaces)
  
  int openBraces = 0;
  bool foundStart = false;
  
  for (int i = startIndex; i < lines.length; i++) {
    final line = lines[i];
    openBraces += line.allMatches('{').length;
    openBraces -= line.allMatches('}').length;
    
    if (openBraces == 0) {
      endIndex = i;
      break;
    }
  }
  
  if (endIndex == -1) {
    print('Could not find _buildProviderServicesTab end');
    return;
  }
  
  print('Replacing lines ${startIndex + 1} to ${endIndex + 1}');
  
  final newContent = [
    '  Widget _buildProviderServicesTab(String providerId) {',
    '    return SharedServicesTab(',
    '      canManage: true,',
    '      providerId: providerId,',
    '    );',
    '  }'
  ];
  
  final updatedLines = [
    ...lines.sublist(0, startIndex),
    ...newContent,
    ...lines.sublist(endIndex + 1)
  ];
  
  await file.writeAsString(updatedLines.join('\n'));
  print('Successfully replaced implementation');
}
