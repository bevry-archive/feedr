# Requires
extendr = require('extendr')
eachr = require('eachr')
{TaskGroup} = require('taskgroup')
typeChecker = require('typechecker')
safefs = require('safefs')
safeps = require('safeps')
balUtil = require('bal-util')
pathUtil = require('path')

# Define
class Feedr
	# Configuration
	config:
		log: null
		logError: null
		tmpPath: null
		cache: true
		cacheTime: 5*60*1000  # 5 minutes
		xmljsOptions: null
		timeout: 10*1000

	# Constructor
	constructor: (config) ->
		# Extend and dereference our configuration
		@config = extendr.extend({},@config,config)

		# Chain
		@

	# Read Feeds
	# feeds = {feedName:feedDetails}, feedDetails={url}
	# next(err,result)
	readFeeds: (feeds,next) ->
		# Prepare
		feedr = @
		config = @config
		{log,logError} = @config
		failures = 0
		isArray = typeChecker.isArray(feeds)
		result = if isArray then [] else {}

		# Tasks
		tasks = new TaskGroup().setConfig(concurrency:0).once 'complete', (err) ->
			log? (if failures then 'warn' else 'debug'), 'Feedr finished fetching', (if failures then "with #{failures} failures" else '')
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
					log? 'debug', "Feedr failed to fetch [#{feedDetails.url}] to [#{feedDetails.path}]"
					logError? err
					++failures
				else
					if isArray
						result.push(data)
					else
						result[feedName] = data

				# Complete
				return complete()

		# Fetch the tmp path we will be writing to
		if config.tmpPath
			tasks.run()
		else
			safeps.getTmpPath (err,tmpPath) ->
				return next(err)  if err
				config.tmpPath = tmpPath
				tasks.run()

		# Chain
		@


	# Read Feed
	# feedDetails = {name,url} or url
	# next(err,data)
	readFeed: (feedDetails,next) ->
		# Prepare
		feedr = @
		config = @config
		{log,logError} = @config

		# Fetch the tmp path we will be writing to
		unless config.tmpPath
			safeps.getTmpPath (err,tmpPath) ->
				return next(err)  if err
				config.tmpPath = tmpPath
				feedr.readFeed(feedDetails, next)
			return @

		# Feed details
		feedDetails = {url:feedDetails,name:feedDetails}  if typeChecker.isString(feedDetails)
		feedDetails.hash ?= require('crypto').createHash('md5').update("feedr-"+JSON.stringify(feedDetails.url)).digest('hex');
		feedDetails.path ?= pathUtil.join(config.tmpPath, feedDetails.hash)
		feedDetails.name ?= feedDetails.hash
		feedDetails.timeout ?= config.timeout

		# Cache time
		feedDetails.cache ?= config.cache
		feedDetails.cacheTime ?= 'auto'
		if !feedDetails.cacheTime
			feedDetails.cacheTime = feedDetails.cache = false
		if feedDetails.cacheTime is 'auto'
			if feedDetails.url.indexOf('github.com') isnt -1
				feedDetails.cacheTime = 60*60*1000  # 1 hour
			else
				feedDetails.cacheTime = 'default'
		if feedDetails.cacheTime is 'default'
			feedDetails.cacheTime = config.cacheTime

		# Special error handling
		if feedDetails.url.indexOf('github.com') isnt -1
			feedDetails.checkResult = (data) ->
				err = null
				try
					data = JSON.parse(data)
					if data.message
						err = new Error(data.message)
				catch _err
					# ignore
				return err

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

		# Write the feed
		writeFeed = (data) ->
			# Store the parsed data in the cache somewhere
			safefs.writeFile feedDetails.path, JSON.stringify(data), (err) ->
				# Check
				return next(err)  if err

				# Return the parsed data
				return next(null, data)

		# Get the file via reading the cached copy
		viaCache = ->
			# Log
			log? 'debug', "Feedr fetched [#{feedDetails.url}] from cache"

			# Check the the file exists
			safefs.exists feedDetails.path, (exists) ->
				# Check it exists
				return next()  unless exists

				# It does exist, so let's continue to read the cached fie
				safefs.readFile feedDetails.path, (err,dataBuffer) ->
					# Check
					return next(err)  if err

					# Parse the cached data
					data = JSON.parse(dataBuffer.toString())

					# Rreturn the parsed cached data
					return next(null, data)

		# Get the file via doing a new request
		viaRequest = ->
			# Log
			log? 'debug', "Feedr is fetching [#{feedDetails.url}] to [#{feedDetails.path}]"

			# Fetch and Save
			balUtil.readPath feedDetails.url, {timeout:feedDetails.timeout}, (err,data) ->
				# If the request fails then we should revert to the cache
				handleError = (err) ->
					return viaCache()  if feedDetails.cache isnt false
					return next(err)
				err ?= feedDetails.checkResult?(data)
				return handleError(err)  if err

				# Trim the requested data
				body = data.toString().trim()

				# Parse the requested data
				# xml
				if /^</.test(body)
					xml2js = require('xml2js')
					xml2jsOptions = config.xml2jsOptions
					if typeChecker.isString(xml2jsOptions)
						xml2jsOptions = xml2js.defaults[xml2jsOptions]
					parser = new xml2js.Parser(xml2jsOptions)
					parser.on 'end', (data) ->
						# write
						return writeFeed(data)

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
					finally
						# Clean the data if desired
						if feedDetails.clean
							log? 'debug', "Feedr is cleaning data from [#{feedDetails.url}]"
							data = cleanData(data)

						# Write
						return writeFeed(data)

		# Check if we should get the data from the cache or do a new request
		if feedDetails.cache is false
			viaRequest()
		else
			balUtil.isPathOlderThan feedDetails.path, feedDetails.cacheTime, (err,older) ->
				# Check
				return next(err)  if err

				# The file doesn't exist, or exists and is old
				if older is null or older is true
					# Refresh
					return viaRequest()
				# The file exists and relatively new
				else
					# Get from cache
					return viaCache()

		# Chain
		@

# Export
module.exports = {Feedr}