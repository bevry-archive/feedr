/* eslint no-sync:0 */
'use strict'

// Require
const {join} = require('path')
const rootPath = join(__dirname, '..')
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
// Helpers

function cleanAtomData (data) {
	return JSON.parse(
		JSON.stringify(data).replace(/"[^"]+?avatar[^"]+?"/g, '"cleaned by feedr test runner"')
	)
}

function cleanContributorsData (data) {
	return data.map((i) => {
		i.contributions = 'cleaned by feedr test runner'
		return i
	})
}

const fixturePath = {
	atom: join(rootPath, 'test-fixtures', 'atom.json'),
	json: join(rootPath, 'test-fixtures', 'package.json'),
	raw: join(rootPath, 'test-fixtures', 'bevry.png'),
	contributors: join(rootPath, 'test-fixtures', 'contributors.json')
}
const fixtureData = {
	atom: cleanAtomData(require(fixturePath.atom)),
	json: require(fixturePath.json),
	raw: fsUtil.readFileSync(fixturePath.raw),
	contributors: cleanContributorsData(require(fixturePath.contributors))
}
const write = true


// =====================================
// Tests

joe.describe('feedr', function (describe, it) {
	const feedrConfig = {
		cache: true,
		log: console.log
	}

	const feedsObject = {
		atom: {
			url: 'https://github.com/bevry/feedr/commits/for-testing.atom'
		},
		json: {
			url: 'https://raw.githubusercontent.com/bevry/feedr/for-testing/package.json'
		},
		raw: {
			url: 'https://raw.githubusercontent.com/bevry/designs/1437c9993a77b24c3ad1856087908b508f3ceec6/bevry/avatars/No%20Shadow/avatar.png'
		},
		contributors: {
			url: `https://api.github.com/repos/bevry/feedr/contributors?per_page=100&client_id=${process.env.GITHUB_CLIENT_ID}&client_secret=${process.env.GITHUB_CLIENT_SECRET}`
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
					expires: new Date(now.getTime() - (1000 * 60))  // a minute from now
				})
			, false)
		})

		it('should be true when using cache and is relevant', function () {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: true
				}, {
					expires: new Date(now.getTime() + (1000 * 60))  // a minute from now
				})
			, true)
		})

		it('should be false when using cache and is not relevant and outside max age', function () {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: 1000 * 60  // a minute from now
				}, {
					expires: new Date(now.getTime() - (1000 * 60)),  // a minute ago
					date: new Date(now.getTime() - (1000 * 60 * 60))  // an hour ago
				})
			, false)
		})

		it('should be true when using cache and is not relevant and within max age', function () {
			const now = new Date()
			equal(
				Feedr.isFeedCacheStillRelevant({
					cache: 1000 * 60  // a minute from now
				}, {
					expires: new Date(now.getTime() - (1000 * 60)),  // a minute ago
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
				result = cleanAtomData(result)
				if ( write ) {
					fsUtil.writeFileSync(fixturePath.atom, JSON.stringify(result, null, '  '))
				}
				deepEqual(result, fixtureData.atom, 'result')
				done()
			})
		})

		it('pass string', function (done) {
			feedr.readFeed(feedsObject.atom.url, function (err, result) {
				errorEqual(err, null, 'error')
				deepEqual(cleanAtomData(result), fixtureData.atom, 'result')
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

	describe('contributors feed', function (describe, it) {
		it('pass', function (done) {
			feedr.readFeed({url: feedsObject.contributors.url, cache: false}, function (err, result) {
				errorEqual(err, null, 'error')
				result = cleanContributorsData(result)
				if ( write ) {
					fsUtil.writeFileSync(fixturePath.contributors, JSON.stringify(result, null, '  '))
				}
				deepEqual(result, fixtureData.contributors, 'result')
				done()
			})
		})
	})

	it('should fetch the feeds correctly when passing an object', function (done) {
		feedr.readFeeds(feedsObject, function (err, result) {
			errorEqual(err, null, 'error')
			deepEqual(cleanAtomData(result.atom), fixtureData.atom, 'atom result')
			deepEqual(result.json, fixtureData.json, 'json result')
			deepEqual(result.raw, fixtureData.raw, 'raw result')
			deepEqual(cleanContributorsData(result.contributors), fixtureData.contributors, 'contributors result')
			equal(result.fail, null, 'fail')
			equal(result.timeout, null, 'timeout')
			done()
		})
	})

	it('should fetch the feeds correctly when passing an array', function (done) {
		feedr.readFeeds(feedsArray, function (err, result) {
			errorEqual(err, null, 'error')
			deepEqual(cleanAtomData(result[0]), fixtureData.atom, 'atom result')
			deepEqual(result[1], fixtureData.json, 'json result')
			deepEqual(result[2], fixtureData.raw, 'raw result')
			deepEqual(cleanContributorsData(result[3]), fixtureData.contributors, 'contributors result')
			equal(result[4], null, 'fail')
			equal(result[5], null, 'timeout')
			done()
		})
	})

	it('should close our timeout server', function () {
		timeoutServer.close()
	})
})
