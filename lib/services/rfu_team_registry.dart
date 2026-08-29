class RfuTeamRegistry {
  static const Map<String, int> _teamToId = {
    'plymstock oaks': 16976,
    'plymstock oaks ii': 16977,
    'plymstock oaks colts': 16979,
    'plymstock': 16976,
    'plymstock albion oaks': 16976,
    
    'old plymothian & mannamedian': 15907,
    'old plymothian': 15907,
    'opm': 15907,
    
    'withycombe': 25785,
    'honiton': 10355,
    'south molton': 19624,
    'brixham': 3314,
    'brixham ii': 3314,
    'tavistock': 21699,
    'exeter saracens': 7777,
    'bideford': 2153,
    'bideford ii': 2153,
    'topsham': 22933,
    'topsham ii': 22933,
    'crediton': 5832,
    'crediton ii': 5832,
    'exmouth': 7823,
    'exmouth ii': 7823,
    'barnstaple': 1479,
    'barnstaple ii': 1479,
    'cullompton': 6003,
    'cullompton ii': 6003,
    'devonport services': 6405,
    'devonport services ii': 6405,
    'ivybridge': 2015,
    'paignton': 2036,
    'torquay athletic': 2038,
    'newton abbot': 2027,
    'okehampton': 2031,
    'sidmouth': 2032,
    'teignmouth': 2033,
    'camborne': 4001,
    'redruth': 2010,
    'cornish pirates': 5644,
    'plymouth albion': 2004,
    
    'bath rugby': 42,
    'exeter chiefs': 41,
    'bristol bears': 43,
    'gloucester rugby': 44,
    'harlequins': 45,
    'leicester tigers': 1005,
    'northampton saints': 1006,
    'saracens': 1007,
    'sale sharks': 1009,
    'newcastle falcons': 1010,
    'coventry': 5722,
    'ealing trailfinders': 7084,
    'bedford blues': 1827,
    'doncaster knights': 6559,
    'ampthill': 632,
    'caldy': 3933,
    'chinnor': 4817,
  };

  /// Returns the canonical RFU Team ID for a club name
  static int? lookupTeamId(String teamName) {
    if (teamName.trim().isEmpty) return null;
    final clean = teamName.trim().toLowerCase();
    
    // 1. Direct match
    if (_teamToId.containsKey(clean)) {
      return _teamToId[clean];
    }
    
    // 2. Substring match
    for (var entry in _teamToId.entries) {
      if (clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    
    // 3. Significant word token match
    final cleanWords = clean.split(' ').where((w) => w.length > 3 && w != 'club' && w != 'rfc' && w != 'colts');
    for (var w in cleanWords) {
      for (var entry in _teamToId.entries) {
        if (entry.key.contains(w)) {
          return entry.value;
        }
      }
    }
    
    return null;
  }
}
