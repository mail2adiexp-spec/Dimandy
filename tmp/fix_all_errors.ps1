$path = 'c:\Users\souna\DEMANDY\ecommerce_app\lib\widgets\shared_products_tab.dart'
$content = Get-Content $path

function Get-LineIndex($pattern, $start=0) {
    for ($i = $start; $i -lt $content.Count; $i++) {
        if ($content[$i] -match $pattern) { return $i }
    }
    return -1
}

# --- FIX ADD DIALOG ---
$addBuilder = 1236 # builder: (context, setState)
$content[$addBuilder] = '      builder: (context) => StatefulBuilder('
$content[$addBuilder+1] = '        builder: (context, setState) {'
$content[$addBuilder+2] = '          String? dialogError;'
$content[$addBuilder+3] = '          return Dialog('

# Fix the messy line 1250 from previous run
$content[1249] = '                    if (dialogError != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)), child: Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)))),'
# Ensure Row is on next line
# Actually line 1250 was the merged line. Let's just fix it by index.
# Line 1250 in Turn 42 is index 1249.

# Fix the catch block for Add
$addCatch = 1862 # } catch (e) {
$content[$addCatch] = '                                   } catch (e) {'
$content[$addCatch+1] = '                                     setState(() {'
$content[$addCatch+2] = '                                       isLoading = false;'
$content[$addCatch+3] = '                                       dialogError = e.toString().Contains("permission-denied") ? "⚠️ Permission Denied: You are not the owner of this product." : "Error: $e";'
$content[$addCatch+4] = '                                     });'
$content[$addCatch+5] = '                                   }'
$content[$addCatch+6] = '                                 },'

# --- FIX EDIT DIALOG ---
$editBuilder = 2002 
$content[$editBuilder] = '      builder: (context) => StatefulBuilder('
$content[$editBuilder+1] = '        builder: (context, setState) {'
$content[$editBuilder+2] = '          String? dialogError;'
$content[$editBuilder+3] = '          return Dialog('

# Add error widget to Edit Dialog (index 2015ish)
# Let's find index of 'children: [' around 2025
$idx = Get-LineIndex 'children: \[' 2020
if ($idx -ne -1) {
    $content[$idx] = "                  children: [ if (dialogError != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)), child: Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)))), "
}

# Fix Edit Catch (line 2676 index 2675)
$editCatch = 2675
$content[$editCatch] = '                                   } catch (e) {'
$content[$editCatch+1] = '                                     setState(() {'
$content[$editCatch+2] = '                                       isLoading = false;'
$content[$editCatch+3] = '                                       dialogError = e.toString().Contains("permission-denied") ? "⚠️ Permission Denied: You cannot edit this product." : "Error: $e";'
$content[$editCatch+4] = '                                     });'
$content[$editCatch+5] = '                                   }'
$content[$editCatch+6] = '                                 },'

$content | Set-Content $path
