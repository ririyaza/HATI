/// SPIN score at/below which access to the app's scenario modules is
/// blocked; only scores above this threshold qualify.
const spinQualifyingThreshold = 40;

bool spinQualifies(int score) => score > spinQualifyingThreshold;
