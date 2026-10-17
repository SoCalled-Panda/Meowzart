/// Gameplay constants. Every value here is data, not policy — the PRD owns the policy.
library;

// --- Lanes and input -------------------------------------------------------
const int kLaneCount = 4;

// --- Timing windows (ms from perfect) --------------------------------------
const double kPerfectMs = 50;
const double kGoodMs = 110;

// --- Scoring ----------------------------------------------------------------
const int kPerfectScore = 300;
const int kGoodScore = 100;
const int kMissScore = 0;

/// Combo multiplier thresholds: `kMultiplierThresholds[i]` is the minimum combo
/// for multiplier `i + 1`.
const List<int> kMultiplierThresholds = [0, 10, 25, 50];

/// Combo milestones that trigger a purr animation + heart burst.
const Set<int> kComboMilestones = {10, 25, 50, 100};

// --- Mood meter -------------------------------------------------------------
const double kMoodMax = 100;
const double kMoodStart = 60;
const double kMoodPerfect = 2;
const double kMoodGood = 1;
const double kMoodMiss = -6;

/// How long scoring is paused when the cat falls asleep.
const double kNapDurationS = 5;

/// Mood the cat wakes at after a nap.
const double kMoodWakeAt = 30;

// --- Stars ------------------------------------------------------------------
const double kStarTwoStarAccuracy = 0.70;
const double kStarThreeStarAccuracy = 0.90;

// --- Song clock -------------------------------------------------------------
/// Seconds of runway before t=0 so the first notes have time to fall.
/// The pipeline must NOT also apply `lead_in_s`.
const double kLeadInS = 2;

/// Snap the interpolated clock back to the audio position beyond this drift.
const double kMaxClockDriftS = 0.040;

// --- Rendering --------------------------------------------------------------
/// Note travel speed in logical pixels per second. Overridden by settings.
const double kDefaultScrollSpeed = 600;
