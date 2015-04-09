Timer = require 'timer'
Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'

exports.getTitle = !-> # prevents title input from showing up when adding the plugin

exports.onInstall = () !->
	newHunt(3) # we'll start with 3 subjects
	Event.create
		unit: 'hunts'
		text: "New Photo Hunt: earn points by completing the various hunts!"

exports.onUpgrade = !->
	# apparently a timer did not fire (or we were out of hunts, next -> 1), correct it
	if 0 < Db.shared.get('next') < Plugin.time()
		Timer.set(Math.floor(Math.random()*7200*1000), 'newRound')

newHuntDelayDays = ->
	maxId = Db.shared.get 'hunts', 'maxId'
	delayDays = 1
	if maxId>7
		openHunts = 0
		deltaTime = false
		for i in [maxId...maxId-7]
			if Db.shared.get 'hunts', i, 'photos', 'maxId'
				break # a photo was posted
			if i>1
				deltaTime = Db.shared.get('hunts', i, 'time') - Db.shared.get('hunts', i-1, 'time')
			if deltaTime is false or deltaTime>10*60*60 # probably not manually triggered, count it
				openHunts++

		if openHunts > 2 # at least 3 consecutive open hunts
			delayDays = Math.pow(openHunts - 2, 2) # 1, 4, 9, 16, 25 days delay
	delayDays


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
		"Wearing a bowtie"
		"Holding a folded paper swan"
		"Climbing a lamp post"
		"Eating a banana"
		"Wearing a onesie"
		"With the supermarket cashier"
		"Holding a cassette walkman"
		"Wearing Superman merchandise"
		"Showing your high school diploma"
		"With a steaming tea kettle"
		"Wearing ice skates"
		"Outside wearing snowboots"
		"Holding an assembled kite"
		"Holding a $100 or €100 bill"
		"Clearly sweating"
		"With just a plain red background"
		"Eating popcorn"
		"In drenching wet clothes"
		"Taking a bath"
		"Wearing a helmet"
		"Donating to a street performer"
		"In a tent"
		"With a traffic light"
		"Lying in a hammock"
		"With your mouth taped shut"
		"With a garden gnome"
		"Slurping spaghetti"
		"In front of a museum"
		"With a vegetable stand"
		"Climbing a fence"
		"Wearing too much lipstick"
		"At a busstop"
		"In the center of a roundabout"
		"Wearing a wig"
		"With a statue"
		"Wearing a clown nose"
		"Wearing your clothes inside out"
		"Wearing two watches"
		"Reading a Playboy magazine"
		"In a McDonalds"
		"Trying to tongue-touch your nose"
		"Licking someone's ear"
		"Kissing someone's boots"
		"Balancing a filled glass on your head"
		"Holding a bowling ball"
		"Swimming"
		"Wearing a suit or evening dress"
		"Talking to a sock puppet"
		"In a garbage bin"
		"Sitting on the toilet"
		"With a lampshade over your head"
		"Reading Harry Potter"
		"Doing a handstand"
		"With an analog phone"
		"Lifting a dumbbell"
		"With your name written on your forehead"
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
		Db.shared.set 'next', 1 # shows 'no more hunts for now'
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
				delayDays = (if cb then 1 else newHuntDelayDays()) # always 1 when manually triggered by user
				nextDayStart = Math.floor(Plugin.time()/86400)*86400 + Math.max(1, delayDays)*86400
				nextTime = nextDayStart + (10*3600) + Math.floor(Math.random()*(12*3600))
				if (nextTime-Plugin.time()) > 3600
					Timer.cancel()
					Timer.set (nextTime-Plugin.time())*1000, 'newHunt'
					Db.shared.set 'next', nextTime

		# we'll only notify when this is about a single new hunt
		if newHunts.length is 1
			subj = newHunts[0]
			Event.create
				unit: 'hunts'
				text: "New Photo Hunt: you " + subj.charAt(0).toLowerCase() + subj.slice(1)

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
	info.time = 0|(Date.now()*.001)
	hunt.set 'photos', maxId, info
	notifyText = ''
	path = null
	if !hunt.get 'winner'
		hunt.set 'winner', maxId
		notifyText = 'won!'
	else
		addComment huntId, "added a runner-up"
		notifyText = 'added a runner-up'
		path = [huntId]

	Event.create
		unit: 'hunts'
		path: path
		text: "Photo Hunt: "+Plugin.userName()+' '+notifyText+' ('+hunt.get('subject')+')'
		sender: Plugin.userId()

addComment = (huntId, comment) !->
	comment =
		t: 0|Plugin.time()
		u: Plugin.userId()
		s: true
		c: comment

	comments = Db.shared.createRef("comments", huntId)
	max = comments.incr 'max'
	comments.set max, comment
