class_name RaceResultText
extends RefCounted
## The race result line posted in chat: the winner, the top payouts, rivalries, treasure and DNFs.

## Most payouts named in the race result line.
const RESULT_PAYOUTS: int = 3
## Most rivalries named in the race result line.
const RESULT_RIVALS: int = 3
## Most DNF names in the race result line.
const RESULT_DNF: int = 3


## The whole result reply for `podium` (GameFlow.podium_ready) and the `dnf` fish (each with a
## "name"): [method build] with the winner, "time is up, nobody finished." when nobody did, or
## empty when nobody raced at all.
static func reply(
	podium: Array[Dictionary], payouts: Array[Dictionary], dnf: Array[Dictionary], treasure: String
) -> String:
	var names: PackedStringArray = []
	for fish: Dictionary in dnf:
		names.append(str(fish["name"]))
	if not podium.is_empty():
		return build(str(podium[0]["name"]), payouts, names, treasure)
	if names.is_empty():
		return ""
	var over: String = "time is up, nobody finished."
	if not treasure.is_empty():
		over += " Treasure: " + treasure
	return over


## "Bubbles won. Payouts: @a +300, @b +200. Rivals: @c beat @d +5. DNF: e, f", with at most
## three payouts, biggest first, three rivalries and three DNF names. Rival rewards are only
## listed under Rivals.
static func build(
	winner: String, payouts: Array[Dictionary], dnf: PackedStringArray = [], treasure: String = ""
) -> String:
	# One entry per viewer: a winner who also bet shows a single total.
	var totals: Dictionary = {}
	var rivals: PackedStringArray = []
	for r: Dictionary in payouts:
		if int(r["payout"]) <= 0:
			continue
		if r.get("kind", "") == "rival":
			rivals.append("@%s beat @%s +%d" % [r["name"], r.get("target", "?"), r["payout"]])
			continue
		var uid: String = str(r.get("user_id", r["name"]))
		if totals.has(uid):
			totals[uid]["payout"] = int(totals[uid]["payout"]) + int(r["payout"])
		else:
			totals[uid] = {"name": r["name"], "payout": int(r["payout"])}
	var paid: Array[Dictionary] = []
	for total: Dictionary in totals.values():
		paid.append(total)
	paid.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["payout"] > b["payout"])
	var parts: PackedStringArray = []
	for r: Dictionary in paid.slice(0, RESULT_PAYOUTS):
		parts.append("@%s +%d" % [r["name"], r["payout"]])
	var sections: PackedStringArray = []
	if not parts.is_empty():
		sections.append("Payouts: " + ", ".join(parts))
	if not rivals.is_empty():
		var beaten: String = "Rivals: " + ", ".join(rivals.slice(0, RESULT_RIVALS))
		if rivals.size() > RESULT_RIVALS:
			beaten += " +%d more" % (rivals.size() - RESULT_RIVALS)
		sections.append(beaten)
	if not treasure.is_empty():
		sections.append("Treasure: " + treasure)
	if not dnf.is_empty():
		var names: String = "DNF: " + ", ".join(dnf.slice(0, RESULT_DNF))
		if dnf.size() > RESULT_DNF:
			names += " +%d more" % (dnf.size() - RESULT_DNF)
		sections.append(names)
	var text: String = "%s won." % winner
	if not sections.is_empty():
		text += " " + ". ".join(sections)
	return text
