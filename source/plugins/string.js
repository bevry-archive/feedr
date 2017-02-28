'use strict'

module.exports.parse = function parseString ({feed, data}, next) {
	// Detect
	const isText = require('istextorbinary').isTextSync(feed.basename, data)
	if ( !isText ) {
		next()
	}
	else {
		// Parse
		next(null, data.toString())
	}
}
