Timer = require 'timer'
Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'

exports.onInstall = () !->
	newHunt(3) # we'll start with 3 subjects
	Event.create
		unit: 'hunts'
		text: "New Photo Hunt: earn points by completing the various hunts!"

exports.onUpgrade = !->
	# apparently a timer did not fire, correct it
	if 0 < Db.shared.get('next') < Plugin.time()
		newHunt()

exports.client_newHunt = exports.newHunt = newHunt = (amount = 1, cb = false) !->
	return if Db.shared.get('next') is -1
		# used to disable my plugins and master instances

	log 'newHunt called, amount '+amount
	hunts = [
		"Brushing your teeth"
		"Riding a bike"
		"Kissing someone"
		"Wearing a cap"
		"And a police officer"
		"Drinking a glass of beer"
		"With a store mannequin"
		"Sitting on a swing"
		"Carrying someone"
		"With someone wearing the same shirt"
		"In an elevator"
		"Eating an ice cream"
		"Hugging a stuffed animal"
		"Wearing yellow sunglasses"
		"Wearing ski goggles"
		"Smoking a cigar"
		"And one of your parents"
		"With whipped cream on your face"
		"Blowing bubble gum"
		"Lying on the street"
		"Wearing a medal"
		"Petting an animal"
		"In a shopping cart"
		"Shampooing your hair"
		"Under a parking sign"
		"Wearing a flower in your hair"
		"On a slide"
		"Under an umbrella"
		"Hugging a tree"
		"In a church"
		"With a Ford Ka"
		"Balancing 3 pillows on your head"
		"Doing push-ups"
		"Holding a (real!) baby"
		"Painting"
		"On a treadmill"
		"Reflected in water"
		"With a guitar"
		"Eating sprouts"
		"Playing with lego"
		"Holding a vinyl record"
		"Inflating a balloon"
		"Talking to a rubber duck"
		"In mid-air"
		"With nine other people"
		"In a library"
		"Standing on a rooftop"
		"Dressed all white"
		"In pyjamas"
		"On a train"
		"With today's newspaper"
		"On a skateboard"
		"With grass in your mouth"
		"In a classroom"
		"Waving a (full-size) flag"
		"Hanging a spoon from your nose"
		"Throwing a frisbee"
		"With a panty hose over your head"
		"Hanging under a table"
		"Posting a letter"
		"In a cinema"
		"Baking pancakes"
		"Taking out the trash"
		"Wrapped in curtains"
		"Drinking through a straw"
		"Lighting a candle"
		"Lying in the grass"
		"Screaming"
		"Wearing earmuffs"
		"Playing darts"
		"In a revolving door"
		"Shaving"
		"Infinitely reflected in two mirrors"
		"Holding a Rubik's Cube"
		"Holding a photo of yourself"
		"On a bridge"
		"Lying in bed"
		"Wearing a pink shirt"
		"In a pub"
		"In sportswear"
		"Petting a horse"
		"Wearing glasses"
		"In the trunk of a car"
		"Playing the piano"
		"Wearing bowtie"
		"Holding a folded paper swan"
		"Climbing a lamp post"
		"Eating a banana"
		"Wearing a onesie"
		"With the supermarket cashier"
	]

	# remove hunts that have taken place already
	if prevHunts = Db.shared.get('hunts')
		for huntId, hunt of prevHunts
			continue if !+huntId
			if (pos = hunts.indexOf(hunt.subject)) >= 0
				hunts.splice pos, 1

	# find some new hunts
	newHunts = []
	while amount-- and hunts.length
		sel = Math.floor(Math.random()*hunts.length)
		newHunts.push hunts[sel]
		hunts.splice sel, 1

	if !newHunts.length
		log 'no more hunts available'
		if cb
			cb.reply true
	else
		log 'selected new hunts: '+JSON.stringify(newHunts)

		for newHunt in newHunts
			maxId = Db.shared.ref('hunts').incr 'maxId'
				# first referencing hunts, as Db.shared.incr 'hunts', 'maxId' is buggy
			Db.shared.set 'hunts', maxId,
				subject: newHunt
				time: 0|(Date.now()*.001)
				photos: {}

			# schedule the next hunt when there are still hunts left
			if hunts.length
				tomorrowStart = Math.floor(Plugin.time()/86400)*86400 + 86400
				nextTime = tomorrowStart + (10*3600) + Math.floor(Math.random()*(12*3600))
				Timer.cancel()
				Timer.set (nextTime-Plugin.time())*1000, 'newHunt'
				Db.shared.set 'next', nextTime

		# we'll only notify when this is about a single new hunt
		if newHunts.length is 1
			subj = newHunts[0]
			Event.create
				unit: 'hunts'
				text: "New Photo Hunt: take a photo of you.. " + subj.charAt(0).toLowerCase() + subj.slice(1)

exports.client_removePhoto = (huntId, photoId, disqualify = false) !->
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	return if !photos.get photoId

	thisUserSubmission = Plugin.userId() is photos.get(photoId, 'userId')
	name = Plugin.userName(photos.get photoId, 'userId')
	possessive = if name.charAt(name.length-1).toLowerCase() is 's' then "'" else "'s"

	if disqualify
		photos.set photoId, 'disqualified', true
	else
		photos.remove photoId

	# find a new winner if necessary
	newWinnerName = null
	if Db.shared.get('hunts', huntId, 'winner') is photoId
		smId = (+k for k, v of photos.get() when !v.disqualified)?.sort()[0]
		Db.shared.set 'hunts', huntId, 'winner', smId
		if smId
			newWinnerName = Plugin.userName(photos.get smId, 'userId')
			Event.create
				unit: 'hunts'
				text: "Photo Hunt: results revised, "+newWinnerName+" won! ("+Db.shared.get('hunts', huntId, 'subject')+")"

	comment = null
	if disqualify
		comment = "disqualified " + name + possessive + " submission"
	else if thisUserSubmission
		comment = "retracted submission"
	else if !thisUserSubmission
		comment = "removed " + name + possessive + " submission"

	if comment
		if newWinnerName
			comment = comment + ", making " + newWinnerName + " the new winner!"
		addComment huntId, comment


exports.onPhoto = (info, huntId) !->
	huntId = huntId[0]
	log 'got photo', JSON.stringify(info), Plugin.userId()

	# test whether the user hasn't uploaded a photo in this hunt yet
	allPhotos = Db.shared.get 'hunts', huntId, 'photos'
	for k, v of allPhotos
		if +v.userId is Plugin.userId()
			log "user #{Plugin.userId()} already submitted a photo for hunt "+huntId
			return

	hunt = Db.shared.ref 'hunts', huntId
	maxId = hunt.incr 'photos', 'maxId'
	hunt.set 'photos', maxId, info
	if !hunt.get 'winner'
		hunt.set 'winner', maxId
		Event.create
			unit: 'hunts'
			text: "Photo Hunt: "+Plugin.userName()+" won! ("+hunt.get('subject')+")"
	else
		addComment huntId, "added a runner-up"

addComment = (huntId, comment) !->
	comment =
		t: 0|Plugin.time()
		u: Plugin.userId()
		s: true
		c: comment

	comments = Db.shared.createRef("comments", huntId)
	max = comments.incr 'max'
	comments.set max, comment
