class CategoryHelpers {
  /// Check if a category supports multi-service booking
  /// (e.g., Barber can offer Haircut, Shave, etc.)
  static bool isMultiServiceCategory(String categoryName) {
    final name = categoryName.toLowerCase();
    return name.contains('barber') ||
           name.contains('napit') ||
           name.contains('salon') ||
           name.contains('bathroom') ||
           name.contains('cleaner') ||
           name.contains('beautician') ||
           name.contains('beauty') ||
           name.contains('cook') ||
           name.contains('carpenter') ||
           name.contains('mehandi') ||
           name.contains('mehndi') ||
           name.contains('henna') ||
           name.contains('milk') ||
           name.contains('painter') ||
           name.contains('paint') ||
           name.contains('water') ||
           name.contains('blood') ||
           name.contains('technician') ||
           name.contains('security') ||
           name.contains('guard');
  }

  static const Map<String, double> commonBloodTestPrices = {
    'CBC (Complete Blood Count)': 300.0,
    'Blood Sugar (Fasting)': 150.0,
    'Blood Sugar (PP)': 150.0,
    'HbA1c': 400.0,
    'Lipid Profile': 500.0,
    'Liver Function Test (LFT)': 600.0,
    'Kidney Function Test (KFT)': 600.0,
    'Thyroid Profile (T3, T4, TSH)': 500.0,
    'Hemoglobin': 150.0,
    'Platelet Count': 200.0,
    'Uric Acid': 250.0,
    'Calcium': 250.0,
    'Vitamin D': 1000.0,
    'Vitamin B12': 800.0,
    'Iron Profile': 700.0,
    'Dengue NS1 Antigen': 600.0,
    'Malaria Parasite': 200.0,
    'Typhoid (Widal)': 250.0,
    'Urine Routine': 150.0,
    'Stool Routine': 150.0,
    'Full Body Checkup': 1500.0,
    'CRP (C-Reactive Protein)': 400.0,
    'ESR (Erythrocyte Sedimentation Rate)': 150.0,
    'Electrolytes (Sodium, Potassium, Chloride)': 500.0,
    'PT/INR (Prothrombin Time)': 400.0,
    'PSA (Prostate Specific Antigen)': 800.0,
    'RA Factor (Rheumatoid Arthritis)': 400.0,
    'Amylase / Lipase': 800.0,
    'Beta HCG (Pregnancy Blood Test)': 600.0,
    'Hepatitis B Surface Antigen': 400.0,
    'Hepatitis C Antibody': 800.0,
    'Vitamin B12 & D3 Profile': 1500.0,
    'Ferritin': 600.0,
    'Homocysteine': 1000.0,
  };

  static List<String> get commonBloodTests => commonBloodTestPrices.keys.toList();

  static const Map<String, double> commonNapitServices = {
    'Haircut': 100.0,
    'Shave': 50.0,
    'Beard Trim': 50.0,
    'Head Massage (15 min)': 100.0,
    'Head Massage (30 min)': 200.0,
    'Face Massage': 150.0,
    'Hair Color (Black)': 200.0,
    'Hair Color (Brown)': 250.0,
    'Facial (Basic)': 300.0,
    'Facial (Gold)': 500.0,
    'Bleach': 150.0,
    'D-Tan': 200.0,
    'Hair Spa': 400.0,
    'Straightening': 1000.0,
    'Keratin Treatment': 2000.0,
  };

  static List<String> get commonNapitServiceNames => commonNapitServices.keys.toList();

  static const Map<String, double> commonBeauticianServices = {
    'Threading (Eyebrows)': 40.0,
    'Threading (Upper Lip)': 20.0,
    'Threading (Forehead)': 20.0,
    'Threading (Full Face)': 150.0,
    'Waxing (Full Arms)': 200.0,
    'Waxing (Half Legs)': 250.0,
    'Waxing (Full Legs)': 400.0,
    'Waxing (Underarms)': 50.0,
    'Waxing (Full Body)': 1500.0,
    'Clean Up': 400.0,
    'Facial (Fruit)': 600.0,
    'Facial (Gold)': 1000.0,
    'Facial (Diamond)': 1500.0,
    'Bleach (Face & Neck)': 250.0,
    'Bleach (Full Back)': 300.0,
    'Bleach (Full Body)': 1200.0,
    'Manicure': 400.0,
    'Pedicure': 500.0,
    'Hair Spa': 800.0,
    'Root Touchup': 1000.0,
    'Global Hair Color': 2500.0,
    'Party Makeup': 2000.0,
    'Bridal Makeup': 10000.0,
    'Nail Art (Basic)': 500.0,
    'Nail Art (Gel)': 1000.0,
    'Nail Extensions': 2000.0,
    'Saree Draping': 500.0,
  };

  static List<String> get commonBeauticianServiceNames => commonBeauticianServices.keys.toList();

  static const Map<String, double> commonSecurityServices = {
    'Unarmed Guard (8 hours)': 800.0,
    'Armed Guard (8 hours)': 1500.0,
    'Event Security (4 hours)': 1200.0,
    'Personal Bodyguard (Daily)': 5000.0,
    'Residential Security (Night Shift)': 12000.0, // Monthly
    'Residential Security (Day Shift)': 10000.0, // Monthly
    'Corporate Security (Month)': 18000.0,
    'Bouncer (Per Hour)': 500.0,
  };

  static List<String> get commonSecurityServiceNames => commonSecurityServices.keys.toList();

  // --- NEW SERVICE LISTS ---

  static const Map<String, double> commonCleaningServices = {
    'Home Cleaning (Full)': 2000.0,
    'Kitchen Cleaning': 1000.0,
    'Bathroom Cleaning': 800.0,
    'Sofa Cleaning': 500.0,
    'Carpet Cleaning': 600.0,
    'Car Cleaning': 500.0,
    'Water Tank Cleaning': 1000.0,
  };

  static const Map<String, double> commonPlumberServices = {
    'Tap Repair': 200.0,
    'Pipe Leakage Repair': 500.0,
    'Water Tank Installation': 1000.0,
    'Basin Installation': 800.0,
    'Toilet Seat Installation': 1200.0,
    'Blockage Removal': 400.0,
    'Motor Installation': 500.0,
  };

  static const Map<String, double> commonElectricianServices = {
    'Fan Installation': 200.0,
    'Switch Repair': 150.0,
    'Tube Light Installation': 150.0,
    'MCB Change': 300.0,
    'Wiring (Per Point)': 200.0,
    'Inverter Installation': 500.0,
    'AC Switch Installation': 400.0,
  };

  static const Map<String, double> commonCarpenterServices = {
    'Furniture Repair': 300.0,
    'Door Lock Installation': 250.0,
    'Door Hinge Repair': 200.0,
    'Curtain Rod Installation': 150.0,
    'Furniture Assembly': 500.0,
    'Bed Repair': 400.0,
  };

  static const Map<String, double> commonACRepairServices = {
    'AC Service (Split)': 500.0,
    'AC Service (Window)': 400.0,
    'Gas Filling': 2500.0,
    'AC Installation': 1500.0,
    'AC Uninstallation': 800.0,
    'PCB Repair': 1000.0,
  };

  static const Map<String, double> commonPainterServices = {
    'Wall Painting (Per SqFt)': 12.0,
    'Texture Painting (Per SqFt)': 25.0,
    'Waterproofing': 5000.0,
    'Wood Polishing': 1000.0,
  };

  // --- HELPER METHODS ---

  static List<String> getServiceSuggestions(String category) {
    final cat = category.toLowerCase();
    
    if (cat.contains('clean')) return commonCleaningServices.keys.toList();
    if (cat.contains('plumb')) return commonPlumberServices.keys.toList();
    if (cat.contains('electr')) return commonElectricianServices.keys.toList();
    if (cat.contains('carpent')) return commonCarpenterServices.keys.toList();
    if (cat.contains('ac') || cat.contains('air')) return commonACRepairServices.keys.toList();
    if (cat.contains('paint')) return commonPainterServices.keys.toList();
    
    if (cat.contains('napit') || cat.contains('barber') || cat.contains('salon')) {
       // Merge Napit + Beautician for salons? Or keep separate?
       // 'Napit' usually refers to Barber. 'Salon' implies unisex or female.
       // Let's return Napit for Barber/Napit, and Beautician for Beauty/Salon/Parlour.
       if (cat.contains('beauty') || cat.contains('parlour')) return commonBeauticianServices.keys.toList();
       return commonNapitServices.keys.toList();
    }
    if (cat.contains('beauty') || cat.contains('parlour')) return commonBeauticianServices.keys.toList();
    
    if (cat.contains('security') || cat.contains('guard')) return commonSecurityServices.keys.toList();
    
    return [];
  }

  static double? getServicePrice(String category, String serviceName) {
    final cat = category.toLowerCase();
    Map<String, double>? sourceMap;

    if (cat.contains('clean')) sourceMap = commonCleaningServices;
    else if (cat.contains('plumb')) sourceMap = commonPlumberServices;
    else if (cat.contains('electr')) sourceMap = commonElectricianServices;
    else if (cat.contains('carpent')) sourceMap = commonCarpenterServices;
    else if (cat.contains('ac') || cat.contains('air')) sourceMap = commonACRepairServices;
    else if (cat.contains('paint')) sourceMap = commonPainterServices;
    else if (cat.contains('napit') || cat.contains('barber')) sourceMap = commonNapitServices;
    else if (cat.contains('beauty') || cat.contains('parlour') || cat.contains('salon')) sourceMap = commonBeauticianServices;
    else if (cat.contains('security') || cat.contains('guard')) sourceMap = commonSecurityServices;

    return sourceMap?[serviceName];
  }
}
