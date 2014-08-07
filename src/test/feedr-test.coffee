# Require
{expect} = require('chai')
joe = require('joe')
{Feedr} = require(__dirname+'/../lib/feedr')

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

	feedr = null

	cleanData = (data) ->
		return JSON.parse JSON.stringify(data).replace(/"https:\/\/0.gravatar.com\/avatar\/.+?"/g, '""')

	fixturePath = __dirname+'/../../test/fixtures.json'
	fixtureData = cleanData require(fixturePath)
	feedsObject =
		"github-atom":
			url: "https://github.com/bevry/feedr/commits/for-testing.atom"
		"fail":
			url: "https://i-dont-exist-123213123123.com/"
		"timeout":
			url: "http://#{timeoutServerAddress}:#{timeoutServerPort}"

	feedsArray = [feedsObject['github-atom'].url]

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
		feedr = new Feedr({
			cache: true
			log: console.log
		})

	it 'should fetch a feed correctly when passing string', (done) ->
		feedr.readFeed {url:feedsObject['github-atom'].url, cache:false}, (err,result) ->
			expect(err, 'error').to.not.exist
			result = cleanData(result)
			require('fs').writeFileSync(fixturePath, JSON.stringify(result, null, '  '))
			expect(result, 'result').to.deep.equal(fixtureData)
			done()

	it 'should fetch a feed correctly when passing object', (done) ->
		feedr.readFeed feedsObject['github-atom'], (err,result) ->
			expect(err, 'error').to.not.exist
			result = cleanData(result)
			expect(result, 'result').to.deep.equal(fixtureData)
			done()

	it 'should fetch the feeds correctly when passing an object', (done) ->
		feedr.readFeeds feedsObject, (err,result) ->
			expect(err, 'error').to.not.exist
			expect(result.fail, 'fail').to.not.exist
			expect(result.timeout, 'timeout').to.not.exist
			result['github-atom'] = cleanData(result['github-atom'])
			expect(result['github-atom'],'result').to.deep.equal(fixtureData)
			done()

	it 'should fetch the feeds correctly when passing an array', (done) ->
		feedr.readFeeds feedsArray, (err,result) ->
			expect(err, 'err').to.not.exist
			result[0] = cleanData(result[0])
			expect(result[0], 'result').to.deep.equal(fixtureData)
			done()

	it 'should close our timeout server', ->
		timeoutServer.close()

