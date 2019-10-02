/* eslint no-sync:0 */
'use strict'

// Require
const path = require('path')
const { equal, deepEqual, errorEqual } = require('assert-helpers')
const kava = require('kava')
const Feedr = require('./')
const fsUtil = require('fs')
const eachr = require('eachr')
const util = require('util')
const getPort = require('get-port')
const {
	fetchGithubAuthQueryString,
	redactGithubAuthQueryString
} = require('githubauthquerystring')
const githubAuthQueryString = fetchGithubAuthQueryString()

// =====================================
// Helpers

function cleanAtomData(data) {
	return JSON.parse(
		JSON.stringify(data).replace(
			/"[^"]+?avatar[^"]+?"/g,
			'"cleaned by feedr test runner"'
		)
	)
}

function cleanContributorsData(data) {
	return data.map(i => {
		i.contributions = 'cleaned by feedr test runner'
		return i
	})
}

const fixturesPath = path.join(__dirname, '..', 'test-fixtures')
const fixturePath = {
	atom: path.join(fixturesPath, 'atom.json'),
	json: path.join(fixturesPath, 'package.json'),
	raw: path.join(fixturesPath, 'bevry.png'),
	contributors: path.join(fixturesPath, 'contributors.json')
}
const fixtureData = {
	atom: cleanAtomData(require(fixturePath.atom)),
	json: require(fixturePath.json),
	raw: fsUtil.readFileSync(fixturePath.raw),
	contributors: cleanContributorsData(require(fixturePath.contributors))
}
let timeoutServer = null
const write = true
const minute = 1000 * 60
const hour = minute * 60

let feedr = null
const feedrConfig = {
	cache: true,
	log(...args) {
		console.log(
			redactGithubAuthQueryString(
				args.map(arg => util.inspect(arg, { colors: true })).join(' ')
			)
		)
	}
}
const feedsObject = {
	atom: {
		url: 'https://github.com/bevry/feedr/commits/for-testing.atom'
	},
	json: {
		url:
			'https://raw.githubusercontent.com/bevry/feedr/for-testing/package.json'
	},
	raw: {
		url:
			'https://raw.githubusercontent.com/bevry/designs/1437c9993a77b24c3ad1856087908b508f3ceec6/bevry/avatars/No%20Shadow/avatar.png'
	},
	contributors: {
		url: `https://api.github.com/repos/bevry/feedr/contributors?per_page=100&${githubAuthQueryString}`
	},
	fail: {
		url: 'https://i-dont-exist-123213123123.com/'
	},
	timeout: {
		url: null // set later
	}
}
const feedsArray = []

// =====================================
// Tests

kava.suite('feedr', function(suite, test) {
	test('setup timeout server', function() {
		const opts = { host: '127.0.0.1' }
		getPort(opts).then(function(port) {
			opts.port = port
			timeoutServer = require('http')
				.createServer(function(req, res) {
					res.writeHead(200, { 'Content-Type': 'text/plain' })
				})
				.listen(opts)
			feedsObject.timeout.url = `http://${opts.host}:${opts.port}`
		})
	})

	test('setup feeds', function() {
		eachr(feedsObject, function(feed) {
			feedsArray.push(feed.url)
		})
	})

	suite('caching relevance works', function(suite, test) {
		test('should be false when not using cache', function() {
			equal(
				Feedr.isFeedCacheStillRelevant(
					{
						cache: false
					},
					{}
				),
				false
			)
		})

		test('should be false when using cache and is not relevant', function() {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant(
					{
						cache: true
					},
					{
						expires: new Date(now.getTime() - minute) // a minute from now
					}
				),
				false
			)
		})

		test('should be true when using cache and is relevant', function() {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant(
					{
						cache: true
					},
					{
						expires: new Date(now.getTime() + minute) // a minute from now
					}
				),
				true
			)
		})

		test('should be false when using cache and is not relevant and outside max age', function() {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant(
					{
						cache: minute // a minute from now
					},
					{
						expires: new Date(now.getTime() - minute), // a minute ago
						date: new Date(now.getTime() - hour) // an hour ago
					}
				),
				false
			)
		})

		test('should be true when using cache and is not relevant and within max age', function() {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant(
					{
						cache: minute // a minute from now
					},
					{
						expires: new Date(now.getTime() - minute), // a minute ago
						date: now
					}
				),
				true
			)
		})
	})

	test('should instantiate correct', function() {
		feedr = new Feedr(feedrConfig)
	})

	suite('atom feed', function(suite, test) {
		test('pass object', function(done) {
			feedr.readFeed(
				{ url: feedsObject.atom.url, parse: 'xml', cache: false },
				function(err, result) {
					errorEqual(err, null, 'error')
					result = cleanAtomData(result)
					if (write) {
						fsUtil.writeFileSync(
							fixturePath.atom,
							JSON.stringify(result, null, '  ')
						)
					}
					deepEqual(result, fixtureData.atom, 'result')
					done()
				}
			)
		})

		test('pass string', function(done) {
			feedr.readFeed(feedsObject.atom.url, function(err, result) {
				errorEqual(err, null, 'error')
				deepEqual(cleanAtomData(result), fixtureData.atom, 'result')
				done()
			})
		})
	})

	suite('json feed', function(suite, test) {
		test('pass object', function(done) {
			feedr.readFeed(
				{ url: feedsObject.json.url, parse: 'json', cache: false },
				function(err, result) {
					errorEqual(err, null, 'error')
					if (write) {
						fsUtil.writeFileSync(
							fixturePath.json,
							JSON.stringify(result, null, '  ')
						)
					}
					deepEqual(result, fixtureData.json, 'result')
					done()
				}
			)
		})

		test('pass string', function(done) {
			feedr.readFeed(feedsObject.json.url, function(err, result) {
				equal(err || null, null, 'error')
				deepEqual(result, fixtureData.json, 'result')
				done()
			})
		})
	})

	suite('raw feed', function(suite, test) {
		test('pass object', function(done) {
			feedr.readFeed(
				{ url: feedsObject.raw.url, parse: 'raw', cache: false },
				function(err, result) {
					errorEqual(err, null, 'error')
					if (write) {
						fsUtil.writeFileSync(fixturePath.raw, result)
					}
					deepEqual(result, fixtureData.raw, 'result')
					done()
				}
			)
		})

		test('pass string', function(done) {
			feedr.readFeed(feedsObject.raw.url, function(err, result) {
				errorEqual(err, null, 'error')
				deepEqual(result, fixtureData.raw, 'result')
				done()
			})
		})
	})

	suite('contributors feed', function(suite, test) {
		test('pass', function(done) {
			feedr.readFeed(
				{ url: feedsObject.contributors.url, cache: false },
				function(err, result) {
					errorEqual(err, null, 'error')
					result = cleanContributorsData(result)
					if (write) {
						fsUtil.writeFileSync(
							fixturePath.contributors,
							JSON.stringify(result, null, '  ')
						)
					}
					deepEqual(result, fixtureData.contributors, 'result')
					done()
				}
			)
		})
	})

	test('should fetch the feeds correctly when passing an object', function(done) {
		feedr.readFeeds(feedsObject, function(err, result) {
			errorEqual(err, null, 'error')
			deepEqual(cleanAtomData(result.atom), fixtureData.atom, 'atom result')
			deepEqual(result.json, fixtureData.json, 'json result')
			deepEqual(result.raw, fixtureData.raw, 'raw result')
			deepEqual(
				cleanContributorsData(result.contributors),
				fixtureData.contributors,
				'contributors result'
			)
			equal(result.fail, null, 'fail')
			equal(result.timeout, null, 'timeout')
			done()
		})
	})

	test('should fetch the feeds correctly when passing an array', function(done) {
		feedr.readFeeds(feedsArray, function(err, result) {
			errorEqual(err, null, 'error')
			deepEqual(cleanAtomData(result[0]), fixtureData.atom, 'atom result')
			deepEqual(result[1], fixtureData.json, 'json result')
			deepEqual(result[2], fixtureData.raw, 'raw result')
			deepEqual(
				cleanContributorsData(result[3]),
				fixtureData.contributors,
				'contributors result'
			)
			equal(result[4], null, 'fail')
			equal(result[5], null, 'timeout')
			done()
		})
	})

	test('should close our timeout server', function() {
		timeoutServer.close()
	})
})
