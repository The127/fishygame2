class_name StatsText
extends RefCounted
## The one-line chat summary for "#stats".


## "Ann: 12 races, 3 wins, 5 podiums | best 18.4s on Zigzag | bets 4 won, 6 lost (-120) | 7 boosts,
## 2 curses". Parts with nothing to show are left out. [param points] supplies the wins.
static func chat_text(points: PointsStore, user_id: String) -> String:
	var stats: ViewerStats = points.stats
	var who: String = points.get_name(user_id)
	var wins: int = points.get_wins(user_id)
	if not stats.has_stats(user_id) and wins == 0:
		return "%s has no stats yet." % who
	var parts: PackedStringArray = []
	parts.append(_count(stats.get_counter(user_id, "races"), "race"))
	parts.append(_count(wins, "win"))
	parts.append(_count(stats.get_counter(user_id, "podiums"), "podium"))
	var dnfs: int = stats.get_counter(user_id, "dnfs")
	if dnfs > 0:
		parts.append("%d DNF" % dnfs)
	var fastest: Dictionary = stats.get_fastest(user_id)
	if not fastest.is_empty():
		var map_name: String = TrackCatalog.get_name_of(str(fastest["map_id"]))
		if map_name.is_empty():
			map_name = str(fastest["map_id"])
		parts.append("best %.1fs on %s" % [float(fastest["time"]), map_name])
	var won: int = stats.get_counter(user_id, "bets_won")
	var lost: int = stats.get_counter(user_id, "bets_lost")
	if won + lost > 0:
		parts.append("bets %d won, %d lost (%+d)" % [won, lost, stats.get_bet_net(user_id)])
	var boosts: int = stats.get_counter(user_id, "boosts")
	var curses: int = stats.get_counter(user_id, "curses")
	if boosts > 0:
		parts.append(_count(boosts, "boost"))
	if curses > 0:
		parts.append(_count(curses, "curse"))
	var eaten: int = stats.get_counter(user_id, "eaten")
	if eaten > 0:
		parts.append("eaten %s" % ("once" if eaten == 1 else "%d times" % eaten))
	return "%s: %s" % [who, ", ".join(parts)]


static func _count(amount: int, noun: String) -> String:
	return "%d %s%s" % [amount, noun, "" if amount == 1 else "s"]
