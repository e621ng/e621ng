(async () => {
	if ($(".video-player").length) {
		// player must be loaded first
		await import("@videojs/html/video/player");

		await Promise.all([
			import("@videojs/html/icons/element"),
			import("@videojs/html/ui/container"),
			import("@videojs/html/ui/controls"),
			import("@videojs/html/ui/gesture"),
			import("@videojs/html/ui/play-button"),
			import("@videojs/html/ui/time"),
		]);
	}
})();
