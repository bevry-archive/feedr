# Require
{expect} = require('chai')
joe = require('joe')
{Feedr} = require(__dirname+'/../lib/feedr')
fsUtil = require('fs')

# =====================================
# Timout Server

timeoutServerAddress = "127.0.0.1"
timeoutServerPort = 9666
timeoutServer = require('http').createServer((req,res) ->
	res.writeHead(200, {'Content-Type': 'text/plain'})
).listen(timeoutServerPort, timeoutServerAddress)


# =====================================
# Tests

joe.describe 'feedr', (describe,it) ->
	fixturePath = {
		atom: __dirname+'/../../test/atom.json'
		json: __dirname+'/../../test/package.json'
		raw: __dirname+'/../../test/bevry.png'
	}
	fixtureData = {}
	feedr = null
	feedrConfig = {
		cache: true
		log: console.log
	}
	write = true

	cleanData = (data) ->
		return JSON.parse JSON.stringify(data).replace(/"https:\/\/0.gravatar.com\/avatar\/.+?"/g, '""')

	feedsObject =
		"atom":
			url: "https://github.com/bevry/feedr/commits/for-testing.atom"
		"json":
			url: "https://raw.githubusercontent.com/bevry/feedr/for-testing/package.json"
		"raw":
			url: "https://raw.githubusercontent.com/bevry/designs/1437c9993a77b24c3ad1856087908b508f3ceec6/bevry/avatars/No%20Shadow/avatar.png"
		"fail":
			url: "https://i-dont-exist-123213123123.com/"
		"timeout":
			url: "http://#{timeoutServerAddress}:#{timeoutServerPort}"

	feedsArray = (value.url  for own key,value of feedsObject)

	describe 'caching relevance works', (describe, it) ->
		it 'should be false when not using cache', ->
			expect(
				Feedr::isFeedCacheStillRelevant({
					cache: false
				}, {})
			).to.equal(false)

		it 'should be false when using cache and is not relevant', ->
			now = new Date()
			expect(
				Feedr::isFeedCacheStillRelevant({
					cache: true
				}, {
					expires: new Date(now.getTime() - 1000 * 60)  # a minute from now
				})
			).to.equal(false)

		it 'should be true when using cache and is relevant', ->
			now = new Date()
			expect(
				Feedr::isFeedCacheStillRelevant({
					cache: true
				}, {
					expires: new Date(now.getTime() + 1000 * 60)  # a minute from now
				})
			).to.equal(true)

		it 'should be false when using cache and is not relevant and outside max age', ->
			now = new Date()
			expect(
				Feedr::isFeedCacheStillRelevant({
					cache: 1000 * 60  # a minute from now
				}, {
					expires: new Date(now.getTime() - 1000 * 60)  # a minute ago
					date: new Date(now.getTime() - 1000 * 60 * 60)  # an hour ago
				})
			).to.equal(false)

		it 'should be true when using cache and is not relevant and within max age', ->
			now = new Date()
			expect(
				Feedr::isFeedCacheStillRelevant({
					cache: 1000 * 60  # a minute from now
				}, {
					expires: new Date(now.getTime() - 1000 * 60)  # a minute ago
					date: now
				})
			).to.equal(true)

	it 'should instantiate correct', ->
		feedr = new Feedr(feedrConfig)


	describe 'atom feed', (describe,it) ->
		it 'pass object', (done) ->
			feedr.readFeed {url:feedsObject['atom'].url, parse:'xml', cache:false}, (err,result) ->
				expect(err, 'error').to.not.exist
				result = cleanData(result)
				fsUtil.writeFileSync(fixturePath.atom, JSON.stringify(result, null, '  '))  if write
				fixtureData.atom = cleanData require(fixturePath.atom)
				expect(result, 'result').to.deep.equal(fixtureData.atom)
				done()

		it 'pass string', (done) ->
			feedr.readFeed feedsObject['atom'].url, (err,result) ->
				expect(err, 'error').to.not.exist
				result = cleanData(result)
				expect(result, 'result').to.deep.equal(fixtureData.atom)
				done()

	describe 'json feed', (describe,it) ->
		it 'pass object', (done) ->
			feedr.readFeed {url:feedsObject['json'].url, parse:'json', cache:false}, (err,result) ->
				expect(err, 'error').to.not.exist
				fsUtil.writeFileSync(fixturePath.json, JSON.stringify(result, null, '  '))  if write
				fixtureData.json = require(fixturePath.json)
				expect(result, 'result').to.deep.equal(fixtureData.json)
				done()

		it 'pass string', (done) ->
			feedr.readFeed feedsObject['json'].url, (err,result) ->
				expect(err, 'error').to.not.exist
				expect(result, 'result').to.deep.equal(fixtureData.json)
				done()

	describe 'raw feed', (describe,it) ->
		it 'pass object', (done) ->
			feedr.readFeed {url:feedsObject['raw'].url, parse:'raw', cache:false}, (err,result) ->
				expect(err, 'error').to.not.exist
				fsUtil.writeFileSync(fixturePath.raw, result)  if write
				fixtureData.raw = fsUtil.readFileSync(fixturePath.raw)
				expect(result, 'result').to.deep.equal(fixtureData.raw)
				done()

		it 'pass string', (done) ->
			feedr.readFeed feedsObject['raw'].url, (err,result) ->
				expect(err, 'error').to.not.exist
				expect(result, 'result').to.deep.equal(fixtureData.raw)
				done()

	it 'should fetch the feeds correctly when passing an object', (done) ->
		feedr.readFeeds feedsObject, (err,result) ->
			expect(err, 'err').to.not.exist
			expect(cleanData(result['atom']), 'atom result').to.deep.equal(fixtureData.atom)
			expect(result['json'], 'json result').to.deep.equal(fixtureData.json)
			expect(result['raw'], 'raw result').to.deep.equal(fixtureData.raw)
			expect(result.fail, 'fail').to.not.exist
			expect(result.timeout, 'timeout').to.not.exist
			done()

	it 'should fetch the feeds correctly when passing an array', (done) ->
		feedr.readFeeds feedsArray, (err,result) ->
			expect(err, 'err').to.not.exist
			expect(cleanData(result[0]), 'atom result').to.deep.equal(fixtureData.atom)
			expect(result[1], 'json result').to.deep.equal(fixtureData.json)
			expect(result[2], 'raw result').to.deep.equal(fixtureData.raw)
			expect(result[3], 'fail').to.not.exist
			expect(result.timeout, 'timeout').to.not.exist
			done()

	it 'should close our timeout server', ->
		timeoutServer.close()

