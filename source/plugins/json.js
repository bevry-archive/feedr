'use strict'

module.exports.parse = function parseJSON ({feedr, feed, response, data}, next) {
	// Detect
	const isJSON =
		feed.parse === 'json' ||
		['.json', '.jsonp', '.js'].indexOf(feed.extension) !== -1  ||
		response.headers['content-type'].indexOf('javascript') !== -1  ||
		response.headers['content-type'].indexOf('json') !== -1
	if ( !isJSON ) {
		next()
		return
	}

	// strip comments, whitespace, and semicolons from the start and finish
	// targets facebook graph api
	data = data.toString().trim().replace(/(^([\s;]|\/\*\*\/)+|[\s;]+$)/g, '')

	// strip the jsonp callback if it exists
	data = data.replace(/^[a-z0-9]+/gi, '').replace(/^\(|\)$/g, '')

	// try parse jsonp
	try {
		data = JSON.parse(data)
	}
	catch ( err ) {
		// strip some dodgy escaping
		data = data.replace(/\\'/g, "'")

		// try parse
		try {
			data = JSON.parse(data)
		}
		catch ( err ) {
			next(err)
			return
		}
	}

	// Clean the data if desired
	if ( feed.clean ) {
		feedr.log('debug', `Feedr is cleaning data from [${feed.url}]`)
		data = feedr.cleanData(data)
	}

	// Write
	next(null, data)
}
