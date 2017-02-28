'use strict'

module.exports.parse = function parseCSON ({feed, response, data}, next) {
	// Detect
	const isCSON = (
		feed.parse === 'cson' ||
		['.coffee', '.cson'].indexOf(feed.extension) !== -1 ||
		response.headers['content-type'].indexOf('coffeescript') !== -1 ||
		response.headers['content-type'].indexOf('cson') !== -1
	)
	if ( !isCSON ) {
		next()
		return
	}

	// Parse
	require('CSON').parseCSONString(data.toString(), next)
}
