'use strict'

module.exports.parse = function parseYAML ({feed, response, data}, next) {
	// Detect
	const isYAML =
		feed.parse === 'yaml' ||
		['.yml', '.yaml'].indexOf(feed.extension) !== -1  ||
		response.headers['content-type'].indexOf('yaml') !== -1
	if ( !isYAML ) {
		next()
		return
	}

	// Parse
	try {
		data = require('js-yaml').load(data.toString().trim())
	}
	catch ( err ) {
		next(err)
		return
	}

	// Write
	next(null, data)
}
