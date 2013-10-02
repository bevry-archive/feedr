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

	fixturePath = __dirname+'/../../test/fixtures.json'
	fixtureData = require(fixturePath)
	feedsObject =
		"github-atom":
			url: "https://github.com/bevry/feedr/commits/for-testing.atom"
		"fail":
			url: "https://i-dont-exist-123213123123.com/"
		"timeout":
			url: "http://#{timeoutServerAddress}:#{timeoutServerPort}"

	feedsArray = [feedsObject['github-atom'].url]

	it 'should instantiate correct', ->
		feedr = new Feedr({
			cache: true
			log: console.log
		})

	it 'should fetch a feed correctly when passing string', (done) ->
		feedr.readFeed feedsObject['github-atom'].url, (err,result) ->
			expect(err,'error').to.not.exist
			#require('fs').writeFileSync(fixturePath, JSON.stringify(result,null,4))
			expect(result,'result').to.deep.equal(fixtureData)
			done()

	it 'should fetch a feed correctly when passing object', (done) ->
		feedr.readFeed feedsObject['github-atom'], (err,result) ->
			expect(err,'error').to.not.exist
			expect(result,'result').to.deep.equal(fixtureData)
			done()

	it 'should fetch the feeds correctly when passing an object', (done) ->
		feedr.readFeeds feedsObject, (err,result) ->
			expect(err,'error').to.not.exist
			expect(result.fail,'fail').to.not.exist
			expect(result.timeout,'timeout').to.not.exist
			expect(result['github-atom'],'result').to.deep.equal(fixtureData)
			done()

	it 'should fetch the feeds correctly when passing an array', (done) ->
		feedr.readFeeds feedsArray, (err,result) ->
			expect(err,'err').to.not.exist
			expect(result[0],'result').to.deep.equal(fixtureData)
			done()

	it 'should close our timeout server', ->
		timeoutServer.close()

