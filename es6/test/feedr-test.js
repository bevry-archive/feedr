// Require
const rootPath = require('path').join(__dirname, '..', '..')
const {equal, deepEqual, errorEqual} = require('assert-helpers')
const joe = require('joe')
const Feedr = require(rootPath)
const fsUtil = require('fs')
const eachr = require('eachr')

// =====================================
// Timout Server

const timeoutServerAddress = '127.0.0.1'
const timeoutServerPort = 9666
const timeoutServer = require('http').createServer(function (req, res) {
	res.writeHead(200, {'Content-Type': 'text/plain'})
}).listen(timeoutServerPort, timeoutServerAddress)


// =====================================
// Tests

joe.describe('feedr', function (describe, it) {
	const fixturePath = {
		atom: rootPath + '/test/atom.json',
		json: rootPath + '/test/package.json',
		raw: rootPath + '/test/bevry.png'
	}
	const fixtureData = {}
	const feedrConfig = {
		cache: true,
		log: console.log,
		plugins: 'xml json'
	}
	const write = false

	const cleanData = function (data) {
		return JSON.parse(
			JSON.stringify(data).replace(/"https:\/\/0.gravatar.com\/avatar\/.+?"/g, '""')
		)
	}

	const feedsObject = {
		atom: {
			url: 'https://github.com/bevry/feedr/commits/for-testing.atom'
		},
		json: {
			url: 'https://raw.githubusercontent.com/bevry/feedr/for-testing/package.json'
		},
		raw: {
			url: 'https://raw.githubusercontent.com/bevry/designs/1437c9993a77b24c3ad1856087908b508f3ceec6/bevry/avatars/No%20Shadow/avatar.png',
		},
		fail: {
			url: 'https://i-dont-exist-123213123123.com/'
		},
		timeout: {
			url: `http://${timeoutServerAddress}:${timeoutServerPort}`
		}
	}

	const feedsArray = []
	eachr(feedsObject, function (feed) {
		feedsArray.push(feed.url)
	})

	describe('caching relevance works', function (describe, it) {
		it('should be false when not using cache', function () {
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: false
				}, {})
			, false)
		})

		it('should be false when using cache and is not relevant', function () {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: true
				}, {
					expires: new Date(now.getTime() - 1000 * 60)  // a minute from now
				})
			, false)
		})

		it('should be true when using cache and is relevant', function () {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: true
				}, {
					expires: new Date(now.getTime() + 1000 * 60)  // a minute from now
				})
			, true)
		})

		it('should be false when using cache and is not relevant and outside max age', function () {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: 1000 * 60  // a minute from now
				}, {
					expires: new Date(now.getTime() - 1000 * 60),  // a minute ago
					date: new Date(now.getTime() - 1000 * 60 * 60)  // an hour ago
				})
			, false)
		})

		it('should be true when using cache and is not relevant and within max age', function () {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: 1000 * 60  // a minute from now
				}, {
					expires: new Date(now.getTime() - 1000 * 60),  // a minute ago
					date: now
				})
			, true)
		})
	})

	let feedr = null
	it('should instantiate correct', function () {
		feedr = new Feedr(feedrConfig)
	})

	describe('atom feed', function (describe, it) {
		it('pass object', function (done) {
			feedr.readFeed({url: feedsObject.atom.url, parse: 'xml', cache: false}, function (err, result) {
				errorEqual(err, null, 'error')
				result = cleanData(result)
				if ( write ) {
					fsUtil.writeFileSync(fixturePath.atom, JSON.stringify(result, null, '  '))
				}
				fixtureData.atom = cleanData(require(fixturePath.atom))
				deepEqual(result, fixtureData.atom, 'result')
				done()
			})
		})

		it('pass string', function (done) {
			feedr.readFeed(feedsObject.atom.url, function (err, result) {
				errorEqual(err, null, 'error')
				result = cleanData(result)
				deepEqual(result, fixtureData.atom, 'result')
				done()
			})
		})
	})

	describe('json feed', function (describe, it) {
		it('pass object', function (done) {
			feedr.readFeed({url: feedsObject.json.url, parse: 'json', cache: false}, function (err, result) {
				errorEqual(err, null, 'error')
				if ( write ) {
					fsUtil.writeFileSync(fixturePath.json, JSON.stringify(result, null, '  '))
				}
				fixtureData.json = require(fixturePath.json)
				deepEqual(result, fixtureData.json, 'result')
				done()
			})
		})

		it('pass string', function (done) {
			feedr.readFeed(feedsObject.json.url, function (err, result) {
				equal(err || null, null, 'error')
				deepEqual(result, fixtureData.json, 'result')
				done()
			})
		})
	})

	describe('raw feed', function (describe, it) {
		it('pass object', function (done) {
			feedr.readFeed({url: feedsObject.raw.url, parse: 'raw', cache: false}, function (err, result) {
				errorEqual(err, null, 'error')
				if ( write ) {
					fsUtil.writeFileSync(fixturePath.raw, result)
				}
				fixtureData.raw = fsUtil.readFileSync(fixturePath.raw)
				deepEqual(result, fixtureData.raw, 'result')
				done()
			})
		})

		it('pass string', function (done) {
			feedr.readFeed(feedsObject.raw.url, function (err, result) {
				errorEqual(err, null, 'error')
				deepEqual(result, fixtureData.raw, 'result')
				done()
			})
		})
	})

	it('should fetch the feeds correctly when passing an object', function (done) {
		feedr.readFeeds(feedsObject, function (err, result) {
			errorEqual(err, null, 'error')
			deepEqual(cleanData(result.atom), fixtureData.atom, 'result')
			deepEqual(result.json, fixtureData.json, 'result')
			deepEqual(result.raw, fixtureData.raw, 'result')
			equal(result.fail, null, 'fail')
			equal(result.timeout, null, 'timeout')
			done()
		})
	})

	it('should fetch the feeds correctly when passing an array', function (done) {
		feedr.readFeeds(feedsArray, function (err, result) {
			errorEqual(err, null, 'error')
			deepEqual(cleanData(result[0]), fixtureData.atom, 'result')
			deepEqual(result[1], fixtureData.json, 'result')
			deepEqual(result[2], fixtureData.raw, 'result')
			equal(result[3], null, 'fail')
			equal(result[4], null, 'timeout')
			done()
		})
	})

	it('should close our timeout server', function () {
		timeoutServer.close()
	})
})
