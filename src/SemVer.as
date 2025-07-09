namespace SemVer {
    string Max(const string &in a, const string &in b) {
        if (a == b) return a;
        if (a.Length == 0) return b;
        if (b.Length == 0) return a;

        auto aParts = a.Split(".");
        auto bParts = b.Split(".");

        int aPart, bPart;

        for (uint i = 0; i < Math::Max(aParts.Length, bParts.Length); i++) {
            aPart = bPart = 0;
            // Try to parse the next part of each version
            if (i < aParts.Length && !Text::TryParseInt(aParts[i], aPart)) {
                trace("Invalid version part in '" + a + "' at index " + i + ": '" + aParts[i] + "'");
            }
            if (i < bParts.Length && !Text::TryParseInt(bParts[i], bPart)) {
                trace("Invalid version part in '" + b + "' at index " + i + ": '" + bParts[i] + "'");
            }
            // compare and return if they differ, loop otherwise
            if (aPart > bPart) return a;
            if (bPart > aPart) return b;
        }
        return a; // they are equal
    }
}
