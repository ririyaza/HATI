/// How long a user who didn't meet the SPIN score requirement must wait
/// before they're allowed to retake the initial assessment.
const spinRetakeCooldown = Duration(days: 14);

DateTime spinRetakeEligibleAt(DateTime completedAt) =>
    completedAt.add(spinRetakeCooldown);
