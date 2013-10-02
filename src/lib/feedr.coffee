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
	# Configuration
	config:
		log: null
		cache: true
		tmpPath: null
		requestOptions: null
		xml2jsOptions: null

	# Constructor
	constructor: (config) ->
		# Extend and dereference our configuration
		@config = extendr.deepExtend({}, @config, config)

		# Chain
		@

	# Log
	log: (args...) ->
		@config.log?(args...)
		@

	# Read Feeds
	# feeds = {feedName:feedDetails}
	# next(err,result)
	readFeeds: (feeds,next) ->
		# Prepare
		feedr = @
		failures = 0

		# Extract
		isArray = typeChecker.isArray(feeds)
		result = if isArray then [] else {}

		# Tasks
		tasks = new TaskGroup().setConfig(concurrency:0).once 'complete', (err) ->
			feedr.log (if failures then 'warn' else 'debug'), 'Feedr finished fetching', (if failures then "with #{failures} failures" else '')
			return next(err,result)

		# Feeds
		eachr feeds, (feedDetails,feedName) -> tasks.addTask (complete) ->
			# Prepare
			if typeChecker.isString(feedDetails)
				feedDetails = {url:feedDetails}
			feedDetails.name ?= feedName

			# Read
			feedr.readFeed feedDetails, (err,data) ->
				# Handle
				if err
					feedr.log 'debug', "Feedr failed to fetch [#{feedDetails.url}] to [#{feedDetails.path}]"
					feedr.log 'err', err
					++failures
				else
					if isArray
						result.push(data)
					else
						result[feedName] = data

				# Complete
				return complete()

		# Fetch the tmp path we will be writing to
		if feedr.config.tmpPath
			tasks.run()
		else
			safeps.getTmpPath (err,tmpPath) ->
				return next(err)  if err
				feedr.config.tmpPath = tmpPath
				tasks.run()

		# Chain
		@


	# Read Feed
	# next(err,data)
	readFeed: (feedDetails,next) ->
		# Prepare
		feedr = @

		# Fetch the tmp path we will be writing to
		unless feedr.config.tmpPath
			safeps.getTmpPath (err,tmpPath) ->
				return next(err)  if err
				feedr.config.tmpPath = tmpPath
				feedr.readFeed(feedDetails, next)
			return @

		# Parse string if necessary
		feedDetails ?= {}
		feedDetails = {url:feedDetails,name:feedDetails}  if typeChecker.isString(feedDetails)

		# Check for url
		return next(new Error('feed url was not supplied'))  unless feedDetails.url

		# Ensure optional
		feedDetails.hash ?= require('crypto').createHash('md5').update("feedr-"+JSON.stringify(feedDetails.url)).digest('hex');
		feedDetails.path ?= pathUtil.join(feedr.config.tmpPath, feedDetails.hash)
		feedDetails.metaPath ?= feedDetails.path+'-meta.json'
		feedDetails.name ?= feedDetails.hash
		feedDetails.cache ?= feedr.config.cache
		useCache = feedDetails.cache

		# Parse option
		feedDetails.parse ?= true
		extname = pathUtil.extname feedDetails.url.replace(/[?#].*/, '')
		if feedDetails.parse is true
			feedDetails.parse =
				if extname in ['.xml', '.atom', '.rss', '.rdf', '.html', '.html']
					'xml'
				else if extname in ['.json', '.jsonp', '.js']
					'json'
				else if extname in ['.yml', '.yaml']
					'yaml'
				else
					false

		# Check parse option
		if feedDetails.parse and feedDetails.parse not in ['xml', 'json', 'yaml']
			return next(new Error("unrecognised parse value: #{feedDetails.parse}"))

		# Request options
		requestOptions = extendr.deepExtend({
			url: feedDetails.url
			timeout: 1*60*1000
		}, feedr.config.requestOptions or {}, feedDetails.requestOptions or {})

		# XML options
		xml2jsOptions = extendr.deepExtend({}, feedr.config.xml2jsOptions or {}, feedDetails.xml2jsOptions or {})

		# Special error handling
		feedDetails.checkResponse = (response,data,next) ->
			if response.url.indexOf('github.com') isnt -1 and data.message
				err = new Error(data.message)
			else
				err = null
			return next(err)

		# Cleanup some response data
		cleanData = (data) ->
			keys = []

			# Discover the keys inside data, and delve deeper
			for own key,value of data
				if typeChecker.isPlainObject(data)
					data[key] = cleanData(value)
				keys.push(key)

			# Check if we are a simple rest object
			# If so, make it a simple value
			if keys.length is 1 and keys[0] is '_content'
				data = data._content

			# Return the result
			return data

		# Read a file
		readFile = (path, next) ->
			# Log
			feedr.log 'debug', "Feedr is reading [#{feedDetails.url}] on [#{path}]"

			# Check the the file exists
			safefs.exists path, (exists) ->
				# Check it exists
				return next(null, null)  unless exists

				# It does exist, so let's continue to read the cached fie
				safefs.readFile path, (err,rawData) ->
					# Check
					return next(err, null)  if err

					# Rreturn the parsed cached data
					return next(null, rawData)

		# Parse a file
		parseFile = (path, next) ->
			# Log
			feedr.log 'debug', "Feedr is parsing [#{feedDetails.url}] on [#{path}]"

			# Parse
			readFile path, (err,rawData) ->
				return next(err, null)  if err or !rawData
				data = JSON.parse(rawData.toString())
				return next(null, data)

		# Write the feed
		writeFeed = (response, data, next) ->
			# Log
			feedr.log 'debug', "Feedr is writing [#{feedDetails.url}] to [#{feedDetails.path}]"

			# Prepare
			writeTasks = new TaskGroup().setConfig(concurrency:0).once 'complete', (err) ->
				return next(err, data, response.headers)

			# Store the meta data in the cache somewhere
			writeTasks.addTask (complete) ->
				safefs.writeFile(feedDetails.metaPath, JSON.stringify(response.headers), complete)

			# Store the parsed data in the cache somewhere
			writeTasks.addTask (complete) ->
				if feedDetails.parse
					rawData = JSON.stringify(data)
				else
					rawData = data
				safefs.writeFile(feedDetails.path, rawData, complete)

			# Fire the write tasks
			writeTasks.run()

		# Get the file via reading the cached copy
		viaCache = (next) ->
			# Log
			feedr.log 'debug', "Feedr is remembering [#{feedDetails.url}] from cache"

			# Prepare
			meta = null
			data = null
			readTasks = new TaskGroup().setConfig(concurrency:0).once 'complete', (err) ->
				return next(err, data, meta)

			# Store the meta data in the cache somewhere
			readTasks.addTask (complete) ->
				parseFile feedDetails.metaPath, (err,result) ->
					return complete(err)  if err or !result
					meta = result
					return complete()

			# Store the parsed data in the cache somewhere
			readTasks.addTask (complete) ->
				readFile feedDetails.path, (err,result) ->
					return complete(err)  if err or !result
					if feedDetails.parse
						data = JSON.parse(result.toString())
					else
						data = result
					return complete()

			# Fire the write tasks
			readTasks.run()

		# Get the file via performing a fresh request
		viaRequest = (next) ->
			# Log
			feedr.log 'debug', "Feedr is fetching [#{feedDetails.url}] to [#{feedDetails.path}]"

			# Add etag if we have it
			if useCache and feedDetails.metaData?.etag
				requestOptions.headers ?= {}
				requestOptions.headers['If-None-Match'] ?= feedDetails.metaData.etag

			# Fetch and Save
			request requestOptions, (err,response,data) ->
				# What should happen if an error occurs
				handleError = (err) ->
					return viaCache(next)  if useCache
					return next(err, data)

				# What should happen if success occurs
				handleSuccess = (data) ->
					return feedDetails.checkResponse response, data, (err) ->
						return handleError(err)  if err
						return writeFeed(response, data, next)

				# Check error
				return handleError(err)  if err

				# Check cache
				return viaCache(next)  if useCache and response.statusCode is 304

				# Parse
				switch feedDetails.parse
					when 'xml'
						# Prepare Parse
						xml2js = require('xml2js')
						parser = new xml2js.Parser(xml2jsOptions)
						parser.on 'end', (data) ->
							# Write
							return handleSuccess(data)

						# Parse
						try
							parser.parseString(data.toString().trim())
						catch err
							return handleError(err)  if err

					when 'json'
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
								return handleError(err)  if err

						# Clean the data if desired
						if feedDetails.clean
							feedr.log 'debug', "Feedr is cleaning data from [#{feedDetails.url}]"
							data = cleanData(data)

						# Write
						return handleSuccess(data)

					when 'yaml'
						# Parse
						try
							data = require('yamljs').parse(data.toString().trim())
						catch err
							return handleError(err)  if err

						# Write
						return handleSuccess(data)

					else
						# Write
						return handleSuccess(data)

		# Refresh if we don't want to use the cache
		return viaRequest(next)  if useCache is false

		# Fetch the latest cache data to check if it is still valid
		parseFile feedDetails.metaPath, (err,metaData) ->
			# There isn't a cache file
			return viaRequest(next)  if err or !metaData

			# Apply to the feed details
			feedDetails.metaData = metaData

			# There is an expires header and it is still valid
			return viaCache(next)  if metaData.expires and (new Date() < new Date(metaData.expires))

			# There was no expires header
			return viaRequest(next)

		# Chain
		@

# Export
module.exports =
	Feedr: Feedr
	create: (args...) ->
		return new Feedr(args...)
