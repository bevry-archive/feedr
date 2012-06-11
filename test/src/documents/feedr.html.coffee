feed = @feedr.feeds.github

ul ->
	for entry in feed.entry
		li datetime: entry.published, ->
			a href: entry.link['@'].href, title: "View on Github", ->
				entry.title