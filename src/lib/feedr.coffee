# Requires
extendr = require('extendr')
eachr = require('eachr')
{TaskGroup} = require('taskgroup')
typeChecker = require('typechecker')
safefs = require('safefs')
safeps = require('safeps')
pathUtil = require('path')
request = require('request')

# Define
class Feedr
	# Helpers
	@Feedr: Feedr
	@create: (args...) -> new @Feedr(args...)
	@subclass: require('csextends')

	# Configuration
	config:
		log: null
		cache: 1000*60*60*24  # one day by default
		tmpPath: null
		requestOptions: null
		xml2jsOptions: null
		plugins: null

	# Constructor
	constructor: (config) ->
		# Prepare
		feedr = @

		# Extend and dereference our configuration
		@config = extendr.deepExtend({}, @config, config)

		# Get the temp path right away
		safeps.getTmpPath (err,tmpPath) ->
			return console.error(err)  if err
			feedr.config.tmpPath = tmpPath
			return

		# Chain
		@

	# Log
	log: (args...) ->
		@config.log?(args...)
		@

	# Read Feeds
	# feeds = {feedName:feed}
	# next(err,result)
	readFeeds: (args...) ->
		# Prepare
		feedr = @
		failures = []

		# Prepare options
		feeds = null
		defaultfeed = {}
		next = null

		# Extract the configuration from the arguments
		for arg,index in args
			switch true
				when typeChecker.isFunction(arg)
					next = arg
				when typeChecker.isArray(arg)
					feeds = arg
				when typeChecker.isPlainObject(arg)
					if index is 0
						feeds = arg
					else
						extendr.extend(defaultfeed, arg)

		# Extract
		isArray = typeChecker.isArray(feeds)
		result = if isArray then [] else {}

		# Tasks
		tasks = TaskGroup.create(concurrency:0, onError:'ignore').done ->
			message = 'Feedr finished fetching'
			if failures.length isnt 0
				message += "with #{failures.length} failures:\n" + failures.map((i) -> i.message).join('\n')
				err = new Error(message)
				feedr.log('warn', err)
			else
				feedr.log('debug', message)

			return next(err, result)

		# Feeds
		eachr feeds, (feed,index) -> tasks.addTask (complete) ->
			# Prepare
			if typeChecker.isString(feed)
				feed = {url: feed}
			feeds[index] = feed = extendr.extend({}, defaultfeed, feed)

			# Read
			feedr.readFeed feed, (err,data) ->
				# Handle
				if err
					feedr.log 'warn', "Feedr failed to fetch [#{feed.url}] to [#{feed.path}]", err.stack
					failures.push(err)
				else
					if isArray
						result.push(data)
					else
						result[index] = data

				# Complete
				return complete(err)

		# Start
		tasks.run()

		# Chain
		@

	# Prepare Feed Details
	prepareFeed: (feed) ->
		# Prepare
		feedr = @

		# Ensure optional
		feed.hash ?= require('crypto').createHash('md5').update("feedr-"+JSON.stringify(feed.url)).digest('hex')
		feed.basename ?= pathUtil.basename feed.url.replace(/[?#].*/, '')
		feed.extension ?= pathUtil.extname(feed.basename)
		feed.name ?= feed.hash + feed.extension
		feed.path ?= pathUtil.join(feedr.config.tmpPath, feed.name)
		feed.metaPath ?= pathUtil.join(feedr.config.tmpPath, feed.name)+'-meta.json'
		feed.cache ?= feedr.config.cache
		feed.parse ?= true
		feed.parse = false  if feed.parse is 'raw'
		feed.check ?= feed.checkResponse  if feed.checkResponse?

		# Return
		return feed

	# Cleanup response data
	cleanData: (data) ->
		keys = []

		# Discover the keys inside data, and delve deeper
		for own key,value of data
			if typeChecker.isPlainObject(data)
				data[key] = @cleanData(value)
			keys.push(key)

		# Check if we are a simple rest object
		# If so, make it a simple value
		if keys.length is 1 and keys[0] is '_content'
			data = data._content

		# Return the result
		return data

	# Read Feed
	# next(err,data)
	readFeed: (args...) ->
		# Prepare
		feedr = @
		feed = {}
		next = null

		# Extract the configuration from the arguments
		for arg in args
			switch true
				when typeChecker.isString(arg)
					feed.url = arg
				when typeChecker.isFunction(arg)
					next = arg
				when typeChecker.isPlainObject(arg)
					extendr.extend(feed, arg)

		# Check for url
		unless feed.url
			noUrlError = new Error('Feed url was not supplied')
			return next(noUrlError, null) 

		# Ensure optional
		feed = @prepareFeed(feed)

		# Plugins
		plugins = (feed.plugins ? plugins) or []
		if typeof plugins is 'string'
			plugins = [plugins]
		if Array.isArray(plugins)
			plugins.forEach (name,index) ->
				if typeof name is 'string'
					try 
						plugins[index] = require('feedr-plugin-'+name)
					catch err
						return next(err, null)

		# Parser
		if feed.parse is 'function'
			# Custom
			parseResponse = (opts, next) ->
				feed.parse opts, (err,data) ->
					return complete(err)  if err
					opts.data  if data?
					return complete()
		else if feed.parse is true
			# Auto
			parseResponse = (opts,next) ->
				checkTasks = new TaskGroup(concurrency:0).done(next)
				eachr plugins, (value, key) ->
					if value.parse?
						checkTasks.addTask (complete) ->
							value.parse opts, (err,data) ->
								return complete(err)  if err
								if data?
									feedr.log 'debug', "Feedr parsed [#{feed.url}] with #{key}"
									opts.data = data
								return complete()
				checkTasks.run()
		else if feed.parse and typeof plugins[feed.parse]?.parse isnt 'function'
			# Missing
			invalidParseError = new Error('Invalid parse vlaue: '+feed.parse)
			return next(invalidParseError, null)
		else
			# Raw
			parseResponse = (opts,complete) -> complete()

		# Checker
		if feed.check is 'function'
			# Custom
			checkResponse = feed.check
		else if feed.check is true
			# Auto
			checkResponse = (opts,next) ->
				checkTasks = new TaskGroup().done(next)
				eachr plugins, (value, key) ->
					if value.check?
						checkTasks.addTask (complete) ->
							value.check(opts, complete)
				checkTasks.run()
		else if feed.check and typeof plugins[feed.check]?.check isnt 'function'
			# Missing
			invalidCheckError = new Error('Invalid check value: '+feed.check)
			return next(invalidCheckError, null)
		else
			# Raw
			checkResponse = (opts,complete) -> complete()

		# Request options
		requestOptions = extendr.deepExtend({
			url: feed.url
			timeout: 1*60*1000
			encoding: null
			headers:
				'User-Agent': 'Wget/1.14 (linux-gnu)'
		}, feedr.config.requestOptions or {}, feed.requestOptions or {})

		# XML options
		xml2jsOptions = extendr.deepExtend({}, feedr.config.xml2jsOptions or {}, feed.xml2jsOptions or {})

		# Read a file
		readFile = (path, complete) ->
			# Log
			feedr.log 'debug', "Feedr is reading [#{feed.url}] on [#{path}], checking exists"

			# Check the the file exists
			safefs.exists path, (exists) ->
				# Check it exists
				unless exists
					# Log
					feedr.log 'debug', "Feedr is reading [#{feed.url}] on [#{path}], it doesn't exist"

					# Exit
					return complete(null, null)

				# Log
				feedr.log 'debug', "Feedr is reading [#{feed.url}] on [#{path}], it exists, now reading"

				# It does exist, so let's continue to read the cached fie
				safefs.readFile path, (err,rawData) ->
					# Check
					if err
						# Log
						feedr.log 'debug', "Feedr is reading [#{feed.url}] on [#{path}], it exists, read failed", err.stack

						# Exit
						return complete(err, null)  if err

					# Log
					feedr.log 'debug', "Feedr is reading [#{feed.url}] on [#{path}], it exists, read completed"

					# Return the parsed cached data
					return complete(null, rawData)

		# Parse a file
		parseFile = (path, next) ->
			# Log
			feedr.log 'debug', "Feedr is parsing [#{feed.url}] on [#{path}]"

			# Parse
			readFile path, (err,rawData) ->
				# Check
				if err or !rawData
					# Log
					feedr.log 'debug', "Feedr is parsing [#{feed.url}] on [#{path}], read failed", err?.stack

					# Exit
					return next(err, null)

				# Attempt
				try
					data = JSON.parse(rawData.toString())
				catch err
					# Log
					feedr.log 'debug', "Feedr is parsing [#{feed.url}] on [#{path}], parse failed", err.stack

					# Exit
					return next(err, null)

				# Log
				feedr.log 'debug', "Feedr is parsing [#{feed.url}] on [#{path}], parse completed"

				# Exit
				return next(null, data)

		# Write the feed
		writeFeed = (response, data, next) ->
			# Log
			feedr.log 'debug', "Feedr is writing [#{feed.url}] to [#{feed.path}]"

			# Prepare
			writeTasks = TaskGroup.create(concurrency:0).done (err) ->
				if err
					# Log
					feedr.log 'debug', "Feedr is writing [#{feed.url}] to [#{feed.path}], write failed", err.stack

					# Exit
					return next(err, null)

				# Log
				feedr.log 'debug', "Feedr is writing [#{feed.url}] to [#{feed.path}], write completed"

				# Exit
				return next(null, data)

			writeTasks.addTask 'store the meta data in a cache somewhere', (complete) ->
				writeData = JSON.stringify(response.headers, null, '  ')
				safefs.writeFile(feed.metaPath, writeData, complete)

			writeTasks.addTask 'store the parsed data in a cache somewhere', (complete) ->
				if feed.parse
					writeData = JSON.stringify(data)
				else
					writeData = data
				safefs.writeFile(feed.path, writeData, complete)

			# Fire the write tasks
			writeTasks.run()

		# Get the file via reading the cached copy
		# next(err, data, meta)
		viaCache = (next) ->
			# Log
			feedr.log 'debug', "Feedr is remembering [#{feed.url}] from cache"

			# Prepare
			meta = null
			data = null
			readTasks = TaskGroup.create(concurrency:0).done (err) ->
				return next(err, data, meta)

			readTasks.addTask 'read the meta data in a cache somewhere', (complete) ->
				parseFile feed.metaPath, (err,result) ->
					return complete(err)  if err or !result
					meta = result
					return complete()

			readTasks.addTask 'read the parsed data in a cache somewhere', (complete) ->
				readFile feed.path, (err,rawData) ->
					return complete(err)  if err or !rawData
					if feed.parse
						try
							data = JSON.parse(rawData.toString())
						catch err
							return complete(err)
					else
						data = rawData
					return complete()

			# Fire the write tasks
			readTasks.run()

		# Get the file via performing a fresh request
		# next(err, data, meta)
		viaRequest = (next) ->
			# Log
			feedr.log 'debug', "Feedr is fetching [#{feed.url}] to [#{feed.path}], requesting"

			# Add etag if we have it
			if feed.cache and feed.metaData?.etag
				requestOptions.headers['If-None-Match'] ?= feed.metaData.etag

			# Fetch and Save
			request requestOptions, (err,response,data) ->
				# Log
				meta = requestOptions.headers
				opts = {feedr, feed, response, data}
				feedr.log 'debug', "Feedr is fetching [#{feed.url}] to [#{feed.path}], requested"

				# What should happen if an error occurs
				handleError = (err) ->
					# Log
					feedr.log 'debug', "Feedr is fetching [#{feed.url}] to [#{feed.path}], error", err.stack

					# Exit
					return viaCache(next)  if feed.cache
					return next(err, opts.data, requestOptions.headers)

				# Check error
				if err
					return handleError(err)

				# Check cache
				if feed.cache and response.statusCode is 304
					return viaCache(next)

				# Determine Parse Type
				parseResponse opts, (err) ->
					return handleError(err)  if err

					# Log
					feedr.log 'debug', "Feedr is fetching [#{feed.url}] to [#{feed.path}], requested, checking"

					# Exit
					return checkResponse opts, (err) ->
						return handleError(err)  if err
						return writeFeed response, opts.data, (err) ->
							return next(err, opts.data, meta)


		# Refresh if we don't want to use the cache
		return viaRequest(next)  if feed.cache is false

		# Fetch the latest cache data to check if it is still valid
		parseFile feed.metaPath, (err,metaData) ->
			# There isn't a cache file
			return viaRequest(next)  if err or !metaData

			# Apply to the feed details
			feed.metaData = metaData

			# There is an expires header and it is still valid
			# cache preferred, use cache if exists, otherwise fall back to relevant
			# cache number, use cache if within number, otherwise fall back to relevant
			return viaCache(next)  if feedr.isFeedCacheStillRelevant(feed, metaData)

			# There was no expires header
			return viaRequest(next)

		# Chain
		@

	# Check to see if the feed is still relevant
	# feed={cache}, cache=boolean/"preferred"/number
	# metaData={expires, date}
	# return boolean
	isFeedCacheStillRelevant: (feed, metaData) ->
		return feed.cache and (
			(
				# User always wants to use cache
				feed.cache is 'preferred'
			) or (
				# If the cache is still relevant according to the website
				metaData.expires and (
					new Date() < new Date(metaData.expires)
				)
			) or (
				# If the cache is still relevant according to the user
				typeChecker.isNumber(feed.cache) and metaData.date and (
					new Date() < new Date(
						new Date(metaData.date).getTime() + feed.cache
					)
				)
			)
		)

# Parsers
plugins = 
	github:
		check: ({feed, data}, next) ->
			if feed.url.indexOf('github.com') isnt -1 and data?.message
				failedResponseError = new Error(data.message)
				return next(failedResponseError)
			return next()

	xml:
		parse: ({feed, response, data}, next) ->
			# Detect
			return next()  unless (
				feed.extension in ['.xml', '.atom', '.rss', '.rdf', '.html', '.html']  or
				response.headers['content-type'].indexOf('xml') isnt -1  or
				response.headers['content-type'].indexOf('html') isnt -1
			)

			# Prepare Parse
			xml2js = require('xml2js')
			parser = new xml2js.Parser(xml2jsOptions)
			parser.on 'end', (data) -> return next(null, data)

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

# Export
module.exports = Feedr