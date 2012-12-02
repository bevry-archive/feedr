# Require
assert = require('assert')
joe = require('joe')
{Feedr} = require(__dirname+'/../lib/feedr')

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
	feedsArray = [feedsObject['github-atom'].url]

	it 'should instantiate correct', ->
		feedr = new Feedr({cache:false})

	it 'should fetch a feed correctly when passing string', (done) ->
		feedr.readFeed feedsObject['github-atom'].url, (err,result) ->
			assert.equal(err||null, null)
			assert.deepEqual(result,fixtureData)
			done()

	it 'should fetch a feed correctly when passing object', (done) ->
		feedr.readFeed feedsObject['github-atom'], (err,result) ->
			assert.equal(err||null, null)
			assert.deepEqual(result,fixtureData)
			done()

	it 'should fetch the feeds correctly when passing an object', (done) ->
		feedr.readFeeds feedsObject, (err,result) ->
			assert.equal(err||null, null)
			assert.equal(result['fail'],undefined)
			assert.deepEqual(result['github-atom'],fixtureData)
			done()

	it 'should fetch the feeds correctly when passing an array', (done) ->
		feedr.readFeeds feedsArray, (err,result) ->
			assert.equal(err||null, null)
			assert.deepEqual(result[0],fixtureData)
			done()

