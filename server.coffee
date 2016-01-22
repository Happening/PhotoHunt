App = require 'app'
Comments = require 'comments'
Db = require 'db'
Event = require 'event'
Timer = require 'timer'

exports.onInstall = () !->
	newHunt(3) # we'll start with 3 subjects

exports.onUpgrade = !->
	# apparently a timer did not fire (or we were out of hunts, next -> 1), correct it
	if 0 < Db.shared.get('next') < App.time()
		Timer.set(Math.floor(Math.random()*7200*1000), 'newHunt')

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
		"In a carwash"
		"Wrapped in toiletpaper"
		"Eating with chopsticks"
		"Eating a pickled herring"
		"Wearing a Hawaiian shirt"
		"Upside down"
		"Trying to bite your big toe"
		"Through a magnifying glass"
		"With someone else also taking a selfie"
		"Riding a broomstick"
		"Wearing a tinfoil hat"
		"Crossing your eyes"
		"With someone over 70 years old"
		"Wearing wooden shoes"
		"Walking a baby stroller"
		"With a bus/taxi driver"
		"Wearing a poncho"
		"With an insect on the tip of your finger"
		"Wearing a towel as a cape"
		"Wearing a mudmask"
		"Sunbathing on a towel"
		"Planking"
		"Squashing a tomato with your hand"
		"Balancing a CD/DVD on your nose"
		"Showing a blue tongue"
		"Wearing a tie rambo-style"
		"Reading a bible"
		"Showing off a trophy cup"
		"Balancing a ball on your finger"
		"Vacuuming"
		"With (candy) hearts in your eyes"
		"Making a shadowbunny with your hand(s)"
		"Wearing a crown or tiara"
		"Passionately hugging a bar stool"
		"In front of a movie poster"
		"Holding a game console controller"
		"On a fatboy sitting bag"
		"At a concert"
		"Drinking a cocktail"
		"Knitting"
		"Wearing a chef's hat"
		"Rope-pulling with a dog"
		"Wearing a showercap"
		"Blowdrying your hair"
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
		log 'selected new hunt(s): '+JSON.stringify(newHunts)

		for newHunt in newHunts
			maxId = Db.shared.ref('hunts').incr 'maxId'
				# first referencing hunts, as Db.shared.incr 'hunts', 'maxId' is buggy
			now = App.time()
			Db.shared.set 'hunts', maxId,
				subject: newHunt
				time: 0|now
				photos: {}

			# schedule the next hunt when there are still hunts left
			if hunts.length
				delayDays = (if cb then 1 else newHuntDelayDays()) # always 1 when manually triggered by user
				nextDayStart = Math.floor(now/86400)*86400 + Math.max(1, delayDays)*86400 + ((new Date).getTimezoneOffset() * 60)
				nextTime = nextDayStart + (10*3600) + Math.floor(Math.random()*(12*3600))
				if (nextTime-now) > 3600
					Timer.cancel()
					Timer.set (nextTime-now)*1000, 'newHunt'
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

	about = photos.get photoId, 'userId'
	thisUserSubmission = App.userId() is about
	name = App.userName(about)
	possessive = if name.charAt(name.length-1).toLowerCase() is 's' then "'" else "'s"

	if disqualify
		photos.set photoId, 'disqualified', true
	else
		photos.remove photoId

	# find a new winner if necessary
	newWinner = newWinnerName = null
	if Db.shared.get('hunts', huntId, 'winner') is photoId
		smId = (+k for k, v of photos.get() when +k and !v.disqualified)?.sort()[0] || null
		Db.shared.set 'hunts', huntId, 'winner', smId # can also remove winner
		if smId
			newWinner = photos.get smId, 'userId'
			newWinnerName = App.userName(newWinner)
			Event.create
				path: [huntId]
				text: "Results revised, "+newWinnerName+" won! ("+Db.shared.get('hunts', huntId, 'subject')+")"

	if disqualify
		if newWinner
			addComment huntId,
				u: App.userId()
				a: about
				w: newWinner
				s: 'winnerAfterDisqualify'
		else
			addComment huntId,
				u: App.userId()
				a: about
				s: 'disqualify'
	else if thisUserSubmission
		if newWinner
			addComment huntId,
				u: App.userId()
				w: newWinner
				s: 'winnerAfterRetract'
		else
			addComment huntId,
				u: App.userId()
				s: 'retract'
	else if !thisUserSubmission
		if newWinner
			addComment huntId,
				u: App.userId()
				a: about
				w: newWinner
				s: 'winnerAfterRemove'
		else
			addComment huntId,
				u: App.userId()
				a: about
				s: 'remove'


exports.onPhoto = (info, huntId) !->
	huntId = huntId[0]
	log 'got photo', JSON.stringify(info), App.userId()

	# test whether the user hasn't uploaded a photo in this hunt yet
	allPhotos = Db.shared.get 'hunts', huntId, 'photos'
	for k, v of allPhotos
		if +v.userId is App.userId()
			log "user #{App.userId()} already submitted a photo for hunt "+huntId
			return

	hunt = Db.shared.ref 'hunts', huntId
	maxId = hunt.incr 'photos', 'maxId'
	info.time = 0|App.time()
	hunt.set 'photos', maxId, info
	notifyText = ''
	if !hunt.get 'winner'
		hunt.set 'winner', maxId
		addComment huntId,
			u: App.userId()
			s: 'winner'
			pushText: App.userName() + ' won!'
	else
		addComment huntId,
			u: App.userId()
			s: 'runnerUp'
			pushText: App.userName() + ' added a runner-up'

addComment = (huntId, comment) !->
	if comment.pushText
		comment.pushText += ' (' + Db.shared.get('hunts', huntId, 'subject') + ')'
	comment.legacyStore = huntId
	comment.path = [huntId]
	Comments.post comment
