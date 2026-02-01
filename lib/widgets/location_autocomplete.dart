import 'package:flutter/material.dart';
import '../utils/locations_data.dart';

class LocationAutocompleteField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Function(City) onSelected;
  final Function(String)? onChanged;
  final TextEditingController? controller;
  final String? initialValue;

  const LocationAutocompleteField({
    super.key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.controller,
    this.initialValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<City>(
      initialValue: TextEditingValue(text: initialValue ?? ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<City>.empty();
        }
        return LocationsData.cities.where((City city) {
          return city.name
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase());
        });
      },
      displayStringForOption: (City option) => option.name,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldTextEditingController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Init controller if available (one-time sync)
         if (controller != null && fieldTextEditingController.text.isEmpty && controller!.text.isNotEmpty) {
           fieldTextEditingController.text = controller!.text;
         }

        return TextField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: Colors.deepPurple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          onChanged: (val) {
             if (controller != null) controller!.text = val;
             if (onChanged != null) onChanged!(val);
          },
        );
      },
      onSelected: onSelected,
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<City> onSelected,
        Iterable<City> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 32, // Width of parent padding
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final City option = options.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.location_city, size: 20),
                      title: Text(option.name),
                      subtitle: Text(option.state),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
