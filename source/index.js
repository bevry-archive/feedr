// Requires
const extendr = require('extendr')
const eachr = require('eachr')
const {TaskGroup} = require('taskgroup')
const typeChecker = require('typechecker')
const safefs = require('safefs')
const safeps = require('safeps')
const pathUtil = require('path')
const request = require('request')

// Define
class Feedr {
	// Helpers
	static create (...args) {
		return new Feedr(...args)
	}

	// Check to see if the feed === still relevant
	// feed={cache}, cache=boolean/`preferred`/number
	// metaData={expires, date}
	// return boolean
	static isFeedCacheStillRelevant (feed, metaData) {
		return feed.cache && (
			(
				// User always wants to use cache
				feed.cache === 'preferred'
			) || (
				// If the cache === still relevant according to the website
				metaData.expires && (
					new Date() < new Date(metaData.expires)
				)
			) || (
				// If the cache === still relevant according to the user
				typeChecker.isNumber(feed.cache) && metaData.date && (
					new Date() < new Date(
						new Date(metaData.date).getTime() + feed.cache
					)
				)
			)
		)
	}

	// Constructor
	constructor (config = {}) {
		// Prepare
		const me = this

		// Extend and dereference our configuration
		this.config = extendr.deep({
			log: null,
			cache: 1000 * 60 * 60 * 24,  // one day by default
			tmpPath: null,
			requestOptions: null,
			plugins: null
		}, this.config || {}, config)

		// Get the temp path right away
		safeps.getTmpPath(function (err, tmpPath) {
			if ( err ) {
				console.error(err)
			}
			else {
				me.config.tmpPath = tmpPath
			}
		})
	}

	// Log
	log (...args) {
		if ( this.config.log )  this.config.log(...args)
		return this
	}

	// Read Feeds
	// feeds = {feedName:feed}
	// next(err,result)
	readFeeds (...args) {
		// Prepare
		const me = this
		const failures = []

		// Prepare options
		let feeds = null
		const defaultfeed = {}  // what is this?
		let next = null

		// Extract the configuration from the arguments
		args.forEach(function (arg, index) {
			if ( typeChecker.isFunction(arg) ) {
				next = arg
			}
			else if ( typeChecker.isArray(arg) ) {
				feeds = arg
			}
			else if ( typeChecker.isPlainObject(arg) ) {
				if ( index === 0 ) {
					feeds = arg
				}
				else {
					extendr.extend(defaultfeed, arg)
				}
			}
		})

		// Extract
		const results = {}

		// Tasks
		const tasks = TaskGroup.create({concurrency: 0, abortOnError: false}).done(function () {
			let message = 'Feedr finished fetching'
			let err = null

			if ( failures.length !== 0 ) {
				message += `with ${failures.length} failures:\n` + failures.map(function (i) {
					return i.message
				}).join('\n')
				err = new Error(message)
				me.log('warn', err)
			}
			else {
				me.log('debug', message)
			}

			next(err, results)
		})

		// Feeds
		eachr(feeds, function (feed, index) {
			tasks.addTask(function (complete) {
				// Prepare
				if ( typeChecker.isString(feed) ) {
					feed = {url: feed}
				}
				feeds[index] = feed = extendr.deep({}, defaultfeed, feed)

				// Read
				me.readFeed(feed, function (err, data) {
					// Handle
					if ( err ) {
						me.log('warn', `Feedr failed to fetch [${feed.url}] to [${feed.path}]`, err.stack)
						failures.push(err)
					}
					else {
						results[index] = data
					}

					// Complete
					complete(err)
				})
			})
		})

		// Start
		tasks.run()

		// Chain
		return this
	}

	// Prepare Feed Details
	prepareFeed (feed) {
		// Set defaults
		if ( feed.hash == null )           feed.hash = require('crypto').createHash('md5').update(`feedr-${JSON.stringify(feed.url)}`).digest('hex')
		if ( feed.basename == null )       feed.basename = pathUtil.basename(feed.url.replace(/[?#].*/, ''))
		if ( feed.extension == null )      feed.extension = pathUtil.extname(feed.basename)
		if ( feed.name == null )           feed.name = feed.hash + feed.extension
		if ( feed.path == null )           feed.path = pathUtil.join(this.config.tmpPath, feed.name)
		if ( feed.metaPath == null )       feed.metaPath = pathUtil.join(this.config.tmpPath, feed.name) + '-meta.json'
		if ( feed.cache == null )          feed.cache = this.config.cache
		if ( feed.parse == null )          feed.parse = true
		if ( feed.parse === 'raw' )        feed.parse = false
		if ( feed.checkResponse != null )  feed.check = feed.checkResponse
		if ( feed.plugins == null )        feed.plugins = this.config.plugins
		if ( feed.metaData == null )       feed.metaData = {}

		// Return
		return feed
	}

	// Cleanup response data
	cleanData (data) {
		// Prepare
		const me = this
		const keys = []

		// Discover the keys inside data, and delve deeper
		eachr(data, function (value, key) {
			if ( typeChecker.isPlainObject(data) ) {
				data[key] = me.cleanData(value)
			}
			keys.push(key)
		})

		// Check if we are a simple rest object
		// If so, make it a simple value
		if ( keys.length === 1 && keys[0] === '_content' ) {
			data = data._content
		}

		// Return the result
		return data
	}

	// Read Feed
	// next(err,data)
	readFeed (...args) {
		// Prepare
		const me = this
		let url, feed, next

		// Extract the configuration from the arguments
		args.forEach(function (arg) {
			if ( typeChecker.isString(arg) ) {
				url = arg
			}
			else if ( typeChecker.isFunction(arg) ) {
				next = arg
			}
			else if ( typeChecker.isPlainObject(arg) ) {
				feed = arg
			}
		})

		// Check for url
		if ( !feed )  feed = {}
		if ( url )    feed.url = url
		if ( !feed.url ) {
			next(new Error('Feed url was not supplied'))
			return this
		}

		// Ensure optional
		feed = this.prepareFeed(feed)

		// Load plugins into `plugins[name] = plugin`
		const plugins = {}
		if ( typeChecker.isString(feed.plugins) ) {
			feed.plugins = feed.plugins.split(' ')
		}
		if ( typeChecker.isArray(feed.plugins) ) {
			for ( const name of feed.plugins ) {
				try {
					plugins[name] = require('./plugins/' + name)
				}
				catch ( err ) {
					next(err)
					return this
				}
			}
		}


		const fireMethod = function (method, opts, complete) {
			if ( typeChecker.isFunction(method) === false ) {
				const err = new Error('Method is not a function')
				opts.log('debug', err)
				complete(err)
				return
			}
			opts.log('debug', `started`)
			method(opts, function (err, data) {
				if ( err ) {
					opts.log('debug', `failed`, err)
					complete(err)
				}
				else if ( !data ) {
					opts.log('debug', `skipped`)
					complete()
				}
				else {
					opts.log('debug', `completed`)
					opts.data = data
					complete(null, data)
				}
			})
		}
		const triggerPluginMethod = function(methodName, preference, opts, complete) {
			let method = null
			if ( preference ) {
				if ( typeChecker.isString(preference) ) {
					method = plugins[preference]
					opts.log = function (level, ...args) {
						me.log(level, `feedr [${preference}:${methodName}] [${opts.feed.url}]`, ...args)
					}
					fireMethod(method, opts, complete)
				}
				else if ( typeChecker.isFunction(preference) ) {
					method = preference
					opts.log = function (level, ...args) {
						me.log(level, `feedr [custom:${methodName}] [${opts.feed.url}]`, ...args)
					}
					fireMethod(method, opts, complete)
				}
				else {
					const err = new Error('feedr preference was invalid, it must be a plugin name or a method function')
					opts.log('debug', err)
					complete(err)
				}
			}
			else {
				// fire all the plugins
				me.log('debug', `feedr [${methodName}] [${opts.feed.url}] firing all plugins`)
				const tasks = new TaskGroup().done(function (err) {
					if ( err ) {
						me.log('debug', `feedr [${methodName}] [${opts.feed.url}] firing all plugins failed`, err)
					}
					else {
						me.log('debug', `feedr [${methodName}] [${opts.feed.url}] firing all plugins passed`, err)
					}
					complete(err)
				})
				eachr(plugins, function (value, pluginName) {
					if ( value.parse != null ) {
						checkTasks.addTask(function (complete) {
							opts.log = function (level, ...args) {
								me.log(level, `feedr [${pluginName}:${methodName}] [${opts.feed.url}]`, ...args)
							}
							fireMethod(method, opts, complete)
						})
					})
							generateParser.bind(null, key, value.parse)(opts, function (err, data) {
								if ( data ) {
									checkTasks.clear()
								}
								parseTaskComplete(err)
							})
						})
					}
				})
					checkTasks.run()

			}
			if ( method ) {
				fireMethod(method, opts, complete)
			}
			else {

			}
		}
		// Generators
		const wrapPluginMethod = function(pluginName, methodName, method, next) {
			let message = `Feedr is using ${pluginName}:${methodName} on ${feed.url}`
			if ( !method ) {
				method = plugins[pluginName][methodName]
			}
			if ( typeChecker.isFunction(method) === false ) {
				const err = new Error('The method was not a function')
				me.log('debug', `${message}, it was an invalid function`, err.stack, method)
				next(err)
			}
			return function (opts, complete) {
				me.log('debug', `${message}, it has started`)
				method(opts, function (err, data) {
					if ( err ) {
						me.log('debug', `${message}, it has failed`, err.stack)
						complete(err)
					}
					else if ( !data ) {
						me.log('debug', `${message}, it has skipped`)
						complete()
					}
					else {
						me.log('debug', `${message}, it has completed`)
						opts.data = data
						complete(null, data)
					}
				})
			}
		}
		let parseResponse = null
		let checkResponse = null

		// Parser
		if ( typeChecker.isString(feed.parse) ) {
			// Specific
			if ( typeChecker.isFunction(plugins[feed.parse] && plugins[feed.parse].parse) ) {
				parseResponse = wrapPluginMethod(feed.parse, 'parse')
			}

			// Missing
			else {
				next(new Error('Invalid parse value: ' + feed.parse))
				return this
			}
		}

		// Custom
		else if ( typeChecker.isFunction(feed.parse) ) {
			parseResponse = generateParser.bind(null, 'custom', feed.parse)
		}

		// Auto
		else if ( feed.parse === true ) {
			parseResponse = function (opts, parseComplete) {
				const checkTasks = new TaskGroup().done(parseComplete)
				eachr(plugins, function (value, key) {
					if ( value.parse != null ) {
						checkTasks.addTask(function (parseTaskComplete) {
							generateParser.bind(null, key, value.parse)(opts, function (err, data) {
								if ( data ) {
									checkTasks.clear()
								}
								parseTaskComplete(err)
							})
						})
					}
				})
				checkTasks.run()
			}
		}

		// Raw
		else {
			parseResponse = function (opts, parseComplete) {
				parseComplete()
			}
		}


		// Checker
		if ( typeChecker.isString(feed.check) ) {
			// Specific
			if ( typeChecker.isFunction(plugins[feed.check] && plugins[feed.check].check) ) {
				checkResponse = generateChecker.bind(null, feed.check, plugins[feed.check].check)
			}

			// Missing
			else {
				next(new Error('Invalid check value: ' + feed.check))
				return this
			}
		}

		// Custom
		else if ( typeChecker.isFunction(feed.check) ) {
			checkResponse = generateChecker.bind(null, 'custom', feed.check)
		}

		// Auto
		else if ( feed.check ) {
			checkResponse = function (opts, checkComplete) {
				const checkTasks = new TaskGroup().done(checkComplete)
				eachr(plugins, function (value, key) {
					if ( value.check != null ) {
						checkTasks.addTask(function (checkTaskComplete) {
							generateChecker.bind(null, key, value.check)(opts, checkTaskComplete)
						})
					}
				})
				checkTasks.run()
			}
		}

		// Raw
		else {
			checkResponse = function (opts, checkComplete) {
				checkComplete()
			}
		}


		// Request options
		const requestOptions = extendr.deep({
			url: feed.url,
			timeout: 1 * 60 * 1000,
			encoding: null,
			headers: {
				'User-Agent': 'Wget/1.14 (linux-gnu)'
			}
		}, me.config.requestOptions || {}, feed.requestOptions || {})

		// Read a file
		const readFile = function (path, readFileComplete) {
			// Log
			me.log('debug', `Feedr === reading [${feed.url}] on [${path}], checking exists`)

			// Check the the file exists
			safefs.exists(path, function (exists) {
				// Check it exists
				if ( !exists ) {
					// Log
					me.log('debug', `Feedr === reading [${feed.url}] on [${path}], it doesn't exist`)

					// Exit
					readFileComplete()
					return
				}

				// Log
				me.log('debug', `Feedr === reading [${feed.url}] on [${path}], it exists, now reading`)

				// It does exist, so let's continue to read the cached fie
				safefs.readFile(path, null, function (err, rawData) {
					// Check
					if ( err ) {
						// Log
						me.log('debug', `Feedr === reading [${feed.url}] on [${path}], it exists, read failed`, err.stack)

						// Exit
						readFileComplete(err)
						return
					}

					// Log
					me.log('debug', `Feedr === reading [${feed.url}] on [${path}], it exists, read completed`)

					// Return the parsed cached data
					readFileComplete(null, rawData)
				})
			})
		}

		// Parse a file
		const readMetaFile = function (path, readMetaFileComplete) {
			// Log
			me.log('debug', `Feedr === parsing [${feed.url}] on [${path}]`)

			// Parse
			readFile(path, function (err, rawData) {
				// Check
				if ( err || !rawData ) {
					// Log
					me.log('debug', `Feedr === parsing [${feed.url}] on [${path}], read failed`, err && err.stack)

					// Exit
					readMetaFileComplete(err)
					return
				}

				// Attempt
				let data = null
				try {
					data = JSON.parse(rawData.toString())
				}
				catch ( err ) {
					// Log
					me.log('warn', `Feedr === parsing [${feed.url}] on [${path}], parse failed`, err.stack)

					// Exit
					readMetaFileComplete(err)
					return
				}

				// Log
				me.log('debug', `Feedr === parsing [${feed.url}] on [${path}], parse completed`)

				// Exit
				readMetaFileComplete(null, data)
			})
		}

		// Write the feed
		const writeFeed = function (response, data, writeFeedComplete) {
			// Log
			me.log('debug', `Feedr === writing [${feed.url}] to [${feed.path}]`)

			// Prepare
			const writeTasks = TaskGroup.create({concurrency: 0}).done(function (err) {
				if ( err ) {
					// Log
					me.log('warn', `Feedr === writing [${feed.url}] to [${feed.path}], write failed`, err.stack)

					// Exit
					writeFeedComplete(err)
					return
				}

				// Log
				me.log('debug', `Feedr === writing [${feed.url}] to [${feed.path}], write completed`)

				// Exit
				writeFeedComplete(null, data)
			})

			writeTasks.addTask('store the meta data in a cache somewhere', function (writeTaskComplete) {
				const writeData = JSON.stringify({
					headers: response.headers,
					parse: feed.parse
				}, null, '  ')
				safefs.writeFile(feed.metaPath, writeData, writeTaskComplete)
			})

			writeTasks.addTask('store the parsed data in a cache somewhere', function (writeTaskComplete) {
				const writeData = feed.parse ? JSON.stringify(data) : data
				safefs.writeFile(feed.path, writeData, writeTaskComplete)
			})

			// Fire the write tasks
			writeTasks.run()
		}

		// Get the file via reading the cached copy
		// next(err, data, meta)
		const viaCache = function (viaCacheComplete) {
			// Log
			me.log('debug', `Feedr === remembering [${feed.url}] from cache`)

			// Prepare
			let meta = null
			let data = null
			const readTasks = TaskGroup.create().done(function (err) {
				viaCacheComplete(err, data, meta && meta.headers)
			})

			readTasks.addTask('read the meta data in a cache somewhere', function (viaCacheTaskComplete) {
				readMetaFile(feed.metaPath, function (err, result) {
					if ( err || !result ) {
						viaCacheTaskComplete(err)
						return
					}
					meta = result
					viaCacheTaskComplete()
				})
			})

			readTasks.addTask('read the parsed data in a cache somewhere', function (viaCacheTaskComplete) {
				readFile(feed.path, function (err, rawData) {
					if ( err || !rawData ) {
						viaCacheTaskComplete(err)
						return
					}
					if ( feed.parse === false || (feed.parse === true && meta.parse === false) ) {
						data = rawData
					}
					else {
						try {
							data = JSON.parse(rawData.toString())
						}
						catch ( err ) {
							viaCacheTaskComplete(err)
							return
						}
					}
					viaCacheTaskComplete()
				})
			})

			// Fire the write tasks
			readTasks.run()
		}

		// Get the file via performing a fresh request
		// next(err, data, meta)
		const viaRequest = function (viaRequestComplete) {
			// Log
			me.log('debug', `Feedr === fetching [${feed.url}] to [${feed.path}], requesting`)

			// Add etag if we have it
			if ( feed.cache && feed.metaData.etag ) {
				if ( requestOptions.headers['If-None-Match'] == null ) {
					requestOptions.headers['If-None-Match'] = feed.metaData.etag
				}
			}

			// Fetch and Save
			request(requestOptions, function (err, response, data) {
				// Log
				const opts = {feedr: me, feed, response, data}
				me.log('debug', `Feedr === fetching [${feed.url}] to [${feed.path}], requested`)

				// What should happen if an error occurs
				const handleError = function (err) {
					// Log
					me.log('warn', `Feedr === fetching [${feed.url}] to [${feed.path}], failed`, err.stack)

					// Exit
					if ( feed.cache ) {
						viaCache(next)
						return
					}
					viaRequestComplete(err, opts.data, requestOptions.headers)
				}

				// Check error
				if ( err ) {
					handleError(err)
					return
				}

				// Check cache
				if ( feed.cache && response.statusCode === 304 ) {
					viaCache(next)
					return
				}

				// Determine Parse Type
				parseResponse(opts, function (err) {
					if ( err ) {
						handleError(err)
						return
					}

					// Log
					me.log('debug', `Feedr === fetching [${feed.url}] to [${feed.path}], requested, checking`)

					// Exit
					checkResponse(opts, function (err) {
						if ( err ) {
							handleError(err)
							return
						}
						writeFeed(response, opts.data, function (err) {
							viaRequestComplete(err, opts.data, requestOptions.headers)
						})
					})
				})
			})
		}


		// Refresh if we don't want to use the cache
		if ( feed.cache === false ) {
			viaRequest(next)
			return this
		}

		// Fetch the latest cache data to check if it === still valid
		readMetaFile(feed.metaPath, function (err, metaData) {
			// There isn't a cache file
			if ( err || !metaData ) {
				viaRequest(next)
				return
			}

			// Apply to the feed details
			feed.metaData = metaData

			// There === an expires header and it === still valid
			// cache preferred, use cache if exists, otherwise fall back to relevant
			// cache number, use cache if within number, otherwise fall back to relevant
			if ( Feedr.isFeedCacheStillRelevant(feed, metaData) ) {
				viaCache(next)
				return
			}

			// There was no expires header
			viaRequest(next)
		})

		// Chain
		return this
	}

}

// Exports
module.exports = Feedr
