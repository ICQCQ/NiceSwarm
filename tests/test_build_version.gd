extends RefCounted
## Unit tests for BuildVersion (scripts/config/build_version.gd) — the build-identity
## label shown in-game and mirrored by the launcher. The BRANCH/COMMIT/COUNT consts are
## the un-stamped "dev" defaults during a test run (only build.ps1/CI rewrite them), so
## this covers the title-casing helper and the from-source default path; the stamped
## "Publish v. 220" path is verified by the build scripts + the launcher's Go mirror.


func run(t) -> void:
	t.suite("build_version")

	# _title_first uppercases ONLY the first char (must match the launcher's Go titleFirst
	# and NOT String.capitalize(), which would split on "_"/spaces and re-case every word).
	t.eq(BuildVersion._title_first("publish"), "Publish", "title-first capitalizes first char")
	t.eq(BuildVersion._title_first("feature_x"), "Feature_x", "title-first leaves '_' words untouched")
	t.eq(BuildVersion._title_first(""), "", "title-first of empty is empty")

	# From-source defaults (consts un-stamped): label() is human-readable, full_label() terse.
	t.eq(BuildVersion.label(), "dev build", "label() is 'dev build' when un-stamped")
	t.eq(BuildVersion.full_label(), "dev", "full_label() is 'dev' when un-stamped")
