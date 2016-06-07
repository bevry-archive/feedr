module.exports = function ({mediator}) {
	mediator.on('parseable', function ({feed, response}) {
		return feed.parse === 'cson' ||
			['.coffee', '.cson'].indexOf(feed.extension) !== -1 ||
			response.headers['content-type'].indexOf('coffeescript') !== -1 ||
			response.headers['content-type'].indexOf('cson') !== -1
	})

	mediator.on('parse', function ({data}, next) {
		require('CSON').parseCSONString(data.toString(), next)
	})
}

module.exports = function () {
	return class {
		onParseable ({feed, response}) {
			return feed.parse === 'cson' ||
				['.coffee', '.cson'].indexOf(feed.extension) !== -1 ||
				response.headers['content-type'].indexOf('coffeescript') !== -1 ||
				response.headers['content-type'].indexOf('cson') !== -1
		}

		onParse ({data}, next) {
			require('CSON').parseCSONString(data.toString(), next)
		}
	}
}
