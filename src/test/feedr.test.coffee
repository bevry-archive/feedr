# Require
assert = require('assert')
joe = require('joe')
{Feedr} = require(__dirname+'/../lib/feedr')

# =====================================
# Tests

joe.describe 'feedr', (describe,it) ->

	feedr = null
	feeds =
		"github-atom":
			url: "https://github.com/bevry/feedr/commits/master.atom"

	it 'should instantiate correct', ->
		feedr = new Feedr()

	it 'should fetch the feeds correctly', (done) ->
		feedr.readFeeds feeds, (err,result) ->
			assert.equal(err||null, null)
			assert.ok(result)
			done()

	it 'should fetch the feeds correctly the second time after caching', (done) ->
		feedr.readFeeds feeds, (err,result) ->
			assert.equal(err||null, null)
			assert.ok(result)
			done()
