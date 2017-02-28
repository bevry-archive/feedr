'use strict'

module.exports.parse = function parseXML ({feedr, feed, response, data}, next) {
	// Detect
	const isXML = feed.parse === 'xml' ||
		['.xml', '.atom', '.rss', '.rdf', '.html', '.html'].indexOf(feed.extension) !== -1  ||
		response.headers['content-type'].indexOf('xml') !== -1  ||
		response.headers['content-type'].indexOf('html') !== -1
	if ( !isXML ) {
		next()
		return
	}

	// XML options
	const xml2jsOptions = require('extendr').deep({}, feedr.config.xml2jsOptions || {}, feed.xml2jsOptions || {})

	// Prepare Parse
	const xml2js = require('xml2js')
	const parser = new xml2js.Parser(xml2jsOptions)
	parser.on('end', function (data) {
		next(null, data)
	})

	// Parse
	try {
		parser.parseString(data.toString().trim())
	}
	catch ( err ) {
		next(err)
	}
}
