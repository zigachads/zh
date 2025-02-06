pub fn strcmp(str1: []const u8, str2: []const u8) bool {
    if (str1.len != str2.len) return false;
    for (str1, str2) |c1, c2| {
        if (c1 != c2) return false;
    }
    return true;
}
