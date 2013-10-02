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
		parseFile = (path, next) ->
			# Log
			feedr.log 'debug', "Feedr is parsing [#{feedDetails.url}] on [#{path}]"

			# Check the the file exists
			safefs.exists path, (exists) ->
				# Check it exists
				return next(null, null)  unless exists

				# It does exist, so let's continue to read the cached fie
				safefs.readFile path, (err,dataBuffer) ->
					# Check
					return next(err, null)  if err

					# Parse the cached data
					data = JSON.parse(dataBuffer.toString())

					# Rreturn the parsed cached data
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
				safefs.writeFile(feedDetails.path, JSON.stringify(data), complete)

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
					return complete(err)  if err
					meta = result
					return complete()

			# Store the parsed data in the cache somewhere
			readTasks.addTask (complete) ->
				parseFile feedDetails.path, (err,result) ->
					return complete(err)  if err
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

				# Trim the requested data
				body = data.toString().trim()

				# Parse the requested data
				# xml
				if /^</.test(body)
					xml2js = require('xml2js')
					parser = new xml2js.Parser(xml2jsOptions)
					parser.on 'end', (data) ->
						# Write
						return handleSuccess(data)

					try
						parser.parseString(body)
					catch err
						return handleError(err)  if err
				else
					# strip comments, whitespace, and semicolons from the start and finish
					# targets facebook graph api
					body = body.replace(/(^([\s\;]|\/\*\*\/)+|[\s\;]+$)/g,'')

					# jsonp/json
					try
						# strip the jsonp callback if it exists, and try parse
						body = body.replace(/^[a-z0-9]+/gi,'').replace(/^\(|\)$/g,'')
						data = JSON.parse(body)
					catch err
						# strip some dodgy escaping and try parse
						try
							body = body.replace(/\\'/g,"'")
							data = JSON.parse(body)
						catch err
							return handleError(err)  if err

					# Clean the data if desired
					if feedDetails.clean
						feedr.log 'debug', "Feedr is cleaning data from [#{feedDetails.url}]"
						data = cleanData(data)

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
