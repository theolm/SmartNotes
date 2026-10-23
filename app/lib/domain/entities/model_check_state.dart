/// Presence alone is never permission to run inference.
enum ModelCheckState { unchecked, checking, ready, missing, corrupt, failed }
