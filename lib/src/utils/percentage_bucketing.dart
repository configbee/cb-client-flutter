// Percentage bucketing for PERCENTAGE_HASH modifier evaluation.
// Canonical spec: internal-docs/SDK-PERCENTAGE-BUCKETING.md

const _saltDelimiter = ':';

int djb2Hash(String str) {
  int hash = 0;
  for (int i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.codeUnitAt(i);
    hash = hash.toSigned(32); // truncate to signed int32
  }
  return hash;
}

// Returns true if (input + salt) hashes into the given percentage bucket.
// percentage=0 always returns false; percentage=100 always returns true.
bool isInPercentageBucket(String input, num percentage, {String salt = ""}) {
  return (djb2Hash(input + _saltDelimiter + salt).toUnsigned(32) / 0x100000000) < (percentage / 100);
}
