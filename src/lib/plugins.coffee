module.exports =
	github:
		check: ({feed, data}, next) ->
			if feed.url.indexOf('github.com') isnt -1 and data?.message
				failedResponseError = new Error(data.message)
				return next(failedResponseError)
			return next()

	xml:
		parse: ({feedr, feed, response, data}, next) ->
			# Detect
			return next()  unless (
				feed.extension in ['.xml', '.atom', '.rss', '.rdf', '.html', '.html']  or
				response.headers['content-type'].indexOf('xml') isnt -1  or
				response.headers['content-type'].indexOf('html') isnt -1
			)

			# XML options
			xml2jsOptions = require('extendr').deepExtend({}, feedr.config.xml2jsOptions or {}, feed.xml2jsOptions or {})
			
			# Prepare Parse
			xml2js = require('xml2js')
			parser = new xml2js.Parser(xml2jsOptions)
			parser.on 'end', (data) ->
				return next(null, data)

			# Parse
			try
				parser.parseString(data.toString().trim())
			catch err
				return next(err)

	cson:
		parse: ({feed, response, data}, next) ->
			# Detect
			return next()  unless (
				feed.extension in ['.coffee', '.cson']  or
				response.headers['content-type'].indexOf('coffeescript') isnt -1  or
				response.headers['content-type'].indexOf('cson') isnt -1
			)

			# Parse
			require('CSON').parse(data.toString(), next)

	json:
		parse: ({feedr, feed, response, data}, next) ->
			# Detect
			return next()  unless (
				feed.extension in ['.json', '.jsonp', '.js']  or
				response.headers['content-type'].indexOf('javascript') isnt -1  or
				response.headers['content-type'].indexOf('json') isnt -1
			)

			# strip comments, whitespace, and semicolons from the start and finish
			# targets facebook graph api
			data = data.toString().trim().replace(/(^([\s\;]|\/\*\*\/)+|[\s\;]+$)/g,'')

			# strip the jsonp callback if it exists
			data = data.replace(/^[a-z0-9]+/gi,'').replace(/^\(|\)$/g,'')

			# try parse jsonp
			try
				data = JSON.parse(data)
			catch err
				# strip some dodgy escaping
				data = data.replace(/\\'/g,"'")

				# try parse
				try
					data = JSON.parse(data)
				catch err
					return next(err)

			# Clean the data if desired
			if feed.clean
				feedr.log 'debug', "Feedr is cleaning data from [#{feed.url}]"
				data = feedr.cleanData(data)

			# Write
			return next(null, data)

	yaml:
		parse: ({feed, response, data}, next) ->
			# Detect
			return next()  unless (
				feed.extension in ['.yml', '.yaml']  or
				response.headers['content-type'].indexOf('yaml') isnt -1
			)

			# Parse
			try
				data = require('yamljs').parse(data.toString().trim())
			catch err
				return next(err)

			# Write
			return next(null, data)

	string:
		parse: ({feed, data}, next) ->
			# Detect
			return next()  unless require('istextorbinary').isTextSync(feed.basename, data)

			# Parse
			return next(null, data.toString())
