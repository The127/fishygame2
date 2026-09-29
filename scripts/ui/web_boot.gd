class_name WebBoot
extends RefCounted
## Web export loading background. The HTML shell paints the page dark ocean while the game
## loads (see html/head_include in export_presets.cfg) so there is no white flash. Once a
## first scene has really been drawn, the page goes transparent again for the OBS browser source.

## Frames to wait after the first draw, so shader compiles do not leave a blank canvas.
const FRAMES_BEFORE_RELEASE: int = 3


## Call from the first scene's _ready. Does nothing outside the web export.
static func release_background() -> void:
	if not OS.has_feature("web"):
		return
	for i: int in FRAMES_BEFORE_RELEASE:
		await RenderingServer.frame_post_draw
	JavaScriptBridge.eval("if (window.fishyBootRelease) window.fishyBootRelease();")
