$path = 'c:\Users\souna\DEMANDY\ecommerce_app\lib\widgets\shared_products_tab.dart'
$content = Get-Content $path

# 1. Update builder to include dialogError state
$content[1236] = '        builder: (context, setState) {'
$content[1237] = '          String? dialogError;'
$content[1238] = '          return Dialog('

# 2. Insert error widget before Row at line 1250 (1249 index)
# Wait, let's find the correct index for Row at line 1250
# 1250:                     Row(
$content[1249] = '                    if (dialogError != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(dialogError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))), Row('

# 3. Update catch block (1863-1871)
$start = 1862
$end = 1870
$newCatch = @(
'                                   } catch (e) {',
'                                     setState(() {',
'                                       isLoading = false;',
'                                       dialogError = e.toString();',
'                                     });',
'                                   }'
)

$newContent = $content[0..($start-1)] + $newCatch + $content[($end+1)..($content.Count-1)]
$newContent | Set-Content $path
