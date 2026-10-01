class_name BuildInfo
extends RefCounted
## Which build this is, for the small tag in the corner of the control panel and home screen.
## The semver lives in project settings (Project > Application > Config > Version): bump the minor
## by hand when it makes sense. CI stamps COMMIT and BUILT_AT into the web export (tools/stamp_build.sh);
## while they are empty, as in local and dev runs, the tag reads "dev".

const COMMIT: String = ""
const BUILT_AT: String = ""


## "v1.0.0 · a1b2c3d · 2026-09-30 16:40 UTC" for a stamped build, "v1.0.0 · dev" otherwise.
static func label() -> String:
	return compose(version(), COMMIT, BUILT_AT)


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func compose(semver: String, commit: String, built_at: String) -> String:
	if commit.is_empty():
		return "v%s · dev" % semver
	if built_at.is_empty():
		return "v%s · %s" % [semver, commit]
	return "v%s · %s · %s" % [semver, commit, built_at]
