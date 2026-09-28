import Foundation

/// Small offline directory so a boarding pass can say "Mexico City" instead of only "MEX".
/// Covers the busiest airports and carriers; anything else shows its code alone.
enum TravelDirectory {
    static func city(for airport: String) -> String? { airports[airport.uppercased()].map { String(localized: $0) } }

    /// City names are localized: "Mexico City" reads "Ciudad de México" in Spanish.
    static let airports: [String: LocalizedStringResource] = [
        "ATL": "Atlanta", "PEK": "Beijing", "PKX": "Beijing", "DXB": "Dubai", "LAX": "Los Angeles",
        "HND": "Tokyo", "NRT": "Tokyo", "ORD": "Chicago", "MDW": "Chicago", "LHR": "London",
        "LGW": "London", "STN": "London", "LTN": "London", "LCY": "London", "PVG": "Shanghai",
        "SHA": "Shanghai", "CDG": "Paris", "ORY": "Paris", "DFW": "Dallas", "DAL": "Dallas",
        "CAN": "Guangzhou", "AMS": "Amsterdam", "HKG": "Hong Kong", "ICN": "Seoul", "GMP": "Seoul",
        "FRA": "Frankfurt", "DEN": "Denver", "DEL": "Delhi", "SIN": "Singapore", "BKK": "Bangkok",
        "DMK": "Bangkok", "JFK": "New York", "LGA": "New York", "EWR": "Newark", "KUL": "Kuala Lumpur",
        "MAD": "Madrid", "SFO": "San Francisco", "SJC": "San Jose", "OAK": "Oakland", "CTU": "Chengdu",
        "LAS": "Las Vegas", "BCN": "Barcelona", "SEA": "Seattle", "MIA": "Miami", "FLL": "Fort Lauderdale",
        "MCO": "Orlando", "IST": "Istanbul", "SAW": "Istanbul", "MUC": "Munich", "YYZ": "Toronto",
        "YVR": "Vancouver", "YUL": "Montréal", "YYC": "Calgary", "SYD": "Sydney", "MEL": "Melbourne",
        "BNE": "Brisbane", "PHX": "Phoenix", "IAH": "Houston", "HOU": "Houston", "CLT": "Charlotte",
        "BOS": "Boston", "MSP": "Minneapolis", "DTW": "Detroit", "PHL": "Philadelphia",
        "IAD": "Washington", "DCA": "Washington", "BWI": "Baltimore", "SLC": "Salt Lake City",
        "SAN": "San Diego", "TPA": "Tampa", "AUS": "Austin", "BNA": "Nashville", "PDX": "Portland",
        "HNL": "Honolulu", "ANC": "Anchorage", "MSY": "New Orleans", "RDU": "Raleigh",
        "MEX": "Mexico City", "NLU": "Mexico City", "CUN": "Cancún", "GDL": "Guadalajara",
        "MTY": "Monterrey", "TIJ": "Tijuana", "SJD": "Los Cabos", "PVR": "Puerto Vallarta",
        "OAX": "Oaxaca", "MID": "Mérida", "BJX": "León", "QRO": "Querétaro", "PBC": "Puebla",
        "BOG": "Bogotá", "MDE": "Medellín", "LIM": "Lima", "SCL": "Santiago", "GRU": "São Paulo",
        "CGH": "São Paulo", "GIG": "Rio de Janeiro", "EZE": "Buenos Aires", "AEP": "Buenos Aires",
        "PTY": "Panama City", "SJO": "San José", "UIO": "Quito", "HAV": "Havana", "SJU": "San Juan",
        "FCO": "Rome", "MXP": "Milan", "LIN": "Milan", "VCE": "Venice", "ZRH": "Zurich", "GVA": "Geneva",
        "VIE": "Vienna", "CPH": "Copenhagen", "ARN": "Stockholm", "OSL": "Oslo", "HEL": "Helsinki",
        "DUB": "Dublin", "LIS": "Lisbon", "OPO": "Porto", "BRU": "Brussels", "PRG": "Prague",
        "WAW": "Warsaw", "BUD": "Budapest", "ATH": "Athens", "BER": "Berlin", "HAM": "Hamburg",
        "DUS": "Düsseldorf", "MAN": "Manchester", "EDI": "Edinburgh", "NCE": "Nice", "PMI": "Palma",
        "AGP": "Málaga", "DOH": "Doha", "AUH": "Abu Dhabi", "RUH": "Riyadh", "JED": "Jeddah",
        "TLV": "Tel Aviv", "CAI": "Cairo", "JNB": "Johannesburg", "CPT": "Cape Town", "NBO": "Nairobi",
        "BOM": "Mumbai", "BLR": "Bengaluru", "MNL": "Manila", "CGK": "Jakarta", "DPS": "Bali",
        "TPE": "Taipei", "KIX": "Osaka", "ITM": "Osaka", "AKL": "Auckland", "SGN": "Ho Chi Minh City",
        "HAN": "Hanoi",
    ]

    static let airlines: [String: String] = [
        "AA": "American Airlines", "DL": "Delta", "UA": "United", "WN": "Southwest", "AS": "Alaska Airlines",
        "B6": "JetBlue", "NK": "Spirit", "F9": "Frontier", "HA": "Hawaiian Airlines", "AC": "Air Canada",
        "WS": "WestJet", "AM": "Aeroméxico", "Y4": "Volaris", "VB": "Viva Aerobus", "AV": "Avianca",
        "CM": "Copa Airlines", "LA": "LATAM", "G3": "GOL", "AD": "Azul", "AR": "Aerolíneas Argentinas",
        "BA": "British Airways", "VS": "Virgin Atlantic", "AF": "Air France", "KL": "KLM", "LH": "Lufthansa",
        "LX": "SWISS", "OS": "Austrian", "SN": "Brussels Airlines", "IB": "Iberia", "VY": "Vueling",
        "UX": "Air Europa", "TP": "TAP Air Portugal", "AZ": "ITA Airways", "SK": "SAS", "AY": "Finnair",
        "EI": "Aer Lingus", "FR": "Ryanair", "U2": "easyJet", "W6": "Wizz Air", "TK": "Turkish Airlines",
        "EK": "Emirates", "QR": "Qatar Airways", "EY": "Etihad", "SV": "Saudia", "LY": "El Al",
        "ET": "Ethiopian", "SA": "South African Airways", "SQ": "Singapore Airlines", "CX": "Cathay Pacific",
        "JL": "Japan Airlines", "NH": "ANA", "KE": "Korean Air", "OZ": "Asiana", "CA": "Air China",
        "MU": "China Eastern", "CZ": "China Southern", "CI": "China Airlines", "BR": "EVA Air",
        "TG": "Thai Airways", "MH": "Malaysia Airlines", "GA": "Garuda Indonesia", "PR": "Philippine Airlines",
        "VN": "Vietnam Airlines", "AI": "Air India", "6E": "IndiGo", "QF": "Qantas", "VA": "Virgin Australia",
        "NZ": "Air New Zealand",
    ]
}
