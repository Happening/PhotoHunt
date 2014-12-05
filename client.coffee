Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Icon = require 'icon'
Loglist = require 'loglist'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Form = require 'form'
Time = require 'time'
Colors = Plugin.colors()
Photo = require 'photo'
Social = require 'social'
{tr} = require 'i18n'

exports.renderSettings = !->
	if Db.shared
		Dom.div !->
			Dom.style margin: '16px 0', textAlign: 'center'
			Dom.b tr "Current hunt: "
			Dom.div !->
				Dom.style marginBottom: '8px'
				Dom.text Db.shared.get('hunts', Db.shared.get('hunts', 'maxId'), 'subject')

			Ui.button 'Proceed to next hunt', !->
				Server.call 'newHunt'

			Ui.button 'test', !->
				Server.call 'test'
	else
		Dom.text tr 'During the game you will find a button here to proceed to the next hunt.'

exports.render = ->
	if Page.state.get(0)
		renderHunt Page.state.get(0), Page.state.get(1)
			# when a second id is passed along that photo is rendered without other stuff around it
		return
	
	rankings = Obs.create()
	Db.shared.ref('hunts').observeEach (hunt) !->
		return if !hunt.get('winner')
		userWon = hunt.get('photos', hunt.get('winner'), 'userId')
		rankings.incr userWon, 10
		Obs.onClean !->
			rankings.incr userWon, -10

		hunt.observeEach 'photos', (photo) !->
			return if photo.get('userId') is userWon or !+photo.key()
			rankings.incr photo.get('userId'), 2
			Obs.onClean !->
				rankings.incr photo.get('userId'), -2

	Obs.observe !->
		log 'rankings', rankings.get()

	Dom.h1 !->
		Dom.style textAlign: 'center'
		Dom.text tr "Best Hunters"

	meInTop3 = false
	Dom.div !->
		Dom.style Box: true, padding: '4px 12px'
		sorted = (+k for k, v of rankings.get()).sort (a, b) -> rankings.get(b) - rankings.get(a)
		if !rankings.get(sorted[0])
			Dom.div !->
				Dom.style Flex: 1, textAlign: 'center', padding: '10px'
				Dom.text tr("No hunts have taken place yet")
		else
			for i in [0..Math.min(2, sorted.length-1)] then do (i) !->
				Dom.div !->
					Dom.style Box: 'center vertical', Flex: 1
					Ui.avatar Plugin.userAvatar(sorted[i]), null, 80
					Dom.div !->
						Dom.style margin: '4px', textAlign: 'center'
						meInTop3 = true if Plugin.userId() is sorted[i]
						Dom.text Plugin.userName(sorted[i])
						Dom.div !->
							Dom.style fontSize: '75%'
							Dom.text tr("%1 points", rankings.get(sorted[i]))

	if !meInTop3
		Dom.div !->
			Dom.style fontSize: '75%', fontStyle: 'italic', paddingBottom: '8px', textAlign: 'center'
			Dom.text tr("(You have %1 point|s)", rankings.get(Plugin.userId())||0)

	Ui.list !->
		lastHasWinner = Db.shared.get 'hunts', (Db.shared.get 'hunts', 'maxId'), 'winner'
		if lastHasWinner
			# next hunt
			Ui.item !->
				Dom.div !->
					Dom.style width: '70px', height: '70px', marginRight: '10px', Box: 'center middle'
					Icon.render data: 'clock2', color: '#aaa', style: { display: 'block' }, size: 34
				Dom.div !->
					Dom.div tr("Next Hunt starts")
					Dom.div !->
						Dom.style fontSize: '120%', fontWeight: 'bold', color: Colors.highlight
						Time.deltaText Db.shared.get('next')

				Dom.onTap !->
					require('modal').show tr("Next Hunt"), tr("The hunt starts every day somewhere between 10am and 10pm. Admins and %1 can trigger a new hunt in the settings.", Plugin.userName(Plugin.ownerId()))


		Db.shared.observeEach 'hunts', (hunt) !->
			Ui.item !->
				log 'hunt', hunt.get()
				winningPhoto = hunt.ref('photos', hunt.get('winner'))
				if key = winningPhoto.get('key')
					Dom.div !->
						Dom.style
							width: '70px'
							height: '70px'
							marginRight: '10px'
							background: "url(#{Photo.url key, 200}) 50% 50% no-repeat"
							backgroundSize: 'cover'
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						Dom.text hunt.get('subject')
						if unread = Social.newComments(hunt.key())
							Ui.unread unread, null, {marginLeft: '4px'}
						if hunt.get('winner')
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text tr("Hunt won by %1", Plugin.userName(hunt.get('photos', hunt.get('winner'), 'userId')))
				else if +hunt.key() is +Db.shared.get('hunts', 'maxId')
					# newest hunt
					Dom.div !->
						Dom.style width: '70px', height: '70px', marginRight: '10px', Box: 'center middle'
						Icon.render data: 'new', style: { display: 'block' }, size: 34
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						Dom.text tr 'Take a photo of you..'
						Dom.div !->
							Dom.style fontSize: '120%', fontWeight: 'bold', color: Colors.highlight
							Dom.text hunt.get('subject')
						log 'checking new comments >>> '+hunt.key()
						if unread = Social.newComments(hunt.key())
							Ui.unread unread, null, {marginLeft: '4px'}

				else
					# no winner yet
					Dom.div !->
						Dom.style width: '70px', height: '70px', marginRight: '10px', Box: 'center middle'
						Icon.render data: 'warn', color: '#aaa', style: { display: 'block' }, size: 34
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						Dom.text hunt.get('subject')
						if unread = Social.newComments(hunt.key())
							Ui.unread unread, null, {marginLeft: '4px'}
						Dom.div !->
							Dom.style fontSize: '75%', marginTop: '6px'
							Dom.text 'No winner yet!'

				Dom.onTap !->
					Page.nav [hunt.key()]

		, (hunt) -> # skip the maxId key
			if +hunt.key()
				-hunt.key()


renderHunt = (huntId, photoId) !->
	Dom.style padding: 0
	Page.setTitle Db.shared.get('hunts', huntId, 'subject')

	winnerId = Db.shared.get 'hunts', huntId, 'winner'
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	if photoId
		mainPhoto = photos.ref photoId
	else
		mainPhoto = photos.ref winnerId

	# remove button
	if mainPhoto.get('userId') is Plugin.userId() or Plugin.userIsAdmin()
		Page.setActions
			icon: Plugin.resourceUri('icon-trash-48.png')
			action: !->
				require('modal').confirm null, tr("Remove photo?"), !->
					Server.sync 'removePhoto', huntId, mainPhoto.key(), !->
						Db.shared.remove 'hunts', huntId, 'winner'
						photos.remove(mainPhoto.key())
					Page.back()

	boxSize = Obs.create()
	Obs.observe !->
		width = Dom.viewport.get('width')
		cnt = (0|(width / 100)) || 1
		boxSize.set(0|(width-((cnt+1)*4))/cnt)

	if !photoId
		allowUpload = Obs.create(true) # when the current use has no photos yet, allow upload
		Db.shared.observeEach 'hunts', huntId, 'photos', (photo) !->
			return if +photo.get('userId') isnt Plugin.userId()
			allowUpload.set false
			Obs.onClean !->
				allowUpload.set true
	
	Dom.div !->
		Dom.style backgroundColor: '#fff', paddingBottom: '2px', borderBottom: '2px solid #ccc'
		# main photo
		contain = Obs.create false
		if mainPhoto and mainPhoto.key()
			Dom.div !->
				Dom.style
					position: 'relative'
					height: Dom.viewport.get('width') + 'px'
					width: Dom.viewport.get('width') + 'px'
					backgroundColor: '#333'
					backgroundImage: Photo.css mainPhoto.get('key'), 800
					backgroundPosition: '50% 50%'
					backgroundSize: if contain.get() then 'contain' else 'cover'
					backgroundRepeat: 'no-repeat'

				Ui.avatar Plugin.userAvatar(mainPhoto.get('userId')), !->
					Dom.style position: 'absolute', bottom: '4px', right: '4px', margin: 0

				Dom.onTap !->
					contain.set !contain.peek()

				Dom.div !->
					Dom.style
						position: 'absolute'
						textAlign: 'right'
						bottom: '10px'
						right: '50px'
						textShadow: '0 1px 0 #000'
						color: '#fff'
					if photoId
						Dom.text tr("Runner-up by %1", Plugin.userName(mainPhoto.get('userId')))
					else
						Dom.text tr("Won by %1", Plugin.userName(mainPhoto.get('userId')))
					Dom.div !->
						Dom.style fontSize: '75%'
						Dom.text tr("%1 point|s", if photoId then 2 else 10)
		else if !photoId
			if allowUpload.get()
				Dom.div !->
					Dom.style textAlign: 'center', padding: '16px'
					addPhoto boxSize.get()-4, huntId
			Dom.div !->
				Dom.style textAlign: 'center', marginBottom: '16px'
				Dom.text tr 'The first one wins 10 points!'

		# we're only rendering other submissions and comments when it's the winner being displayed
		if !photoId
			if mainPhoto and mainPhoto.key()
				Dom.div !->
					Dom.style padding: '2px'

					Dom.h2 !->
						Dom.style margin: '8px 2px 4px 2px'
						Dom.text tr "Runners-up (2 points)"

					photos = Db.shared.ref 'hunts', huntId, 'photos'
					photos.observeEach (photo) !->
						return if +photo.key() is winnerId
						Dom.div !->
							Dom.cls 'photo'
							Dom.style
								display: 'inline-block'
								position: 'relative'
								margin: '2px'
								height: (boxSize.get()) + 'px'
								width: (boxSize.get()) + 'px'
								backgroundImage: Photo.css photo.get('key'), 200
								backgroundSize: 'cover'
								backgroundPosition: '50% 50%'
								backgroundRepeat: 'no-repeat'
							Ui.avatar Plugin.userAvatar(photo.get('userId')), !->
								Dom.style position: 'absolute', bottom: '4px', right: '4px', margin: 0
							Dom.onTap !->
								Page.nav [huntId, photo.key()]
					, (photo) ->
						if +photo.key()
							photo.key()

					if allowUpload.get()
						addPhoto boxSize.get()-4, huntId
					else if photos.count().get()<=2 # maxId is also counted
						Dom.div !->
							Dom.style padding: '2px', color: '#aaa'
							Dom.text tr "No runners-up submitted"

	if !photoId
		log 'comments >>> '+huntId
		Social.renderComments(huntId)

addPhoto = (size, huntId) !->
	Dom.div !->
		Dom.cls 'add'
		Dom.style
			display: 'inline-block'
			position: 'relative'
			verticalAlign: 'top'
			margin: '2px'
			background:  "url(#{Plugin.resourceUri('addphoto.png')}) 50% 50% no-repeat"
			backgroundSize: '32px'
			border: 'dashed 2px #aaa'
			height: size + 'px'
			width: size + 'px'
		Dom.onTap !->
			Photo.pick 'camera', [huntId]

Dom.css
	'.add.tap::after, .photo.tap::after':
		content: '""'
		display: 'block'
		position: 'absolute'
		left: 0
		right: 0
		top: 0
		bottom: 0
		backgroundColor: 'rgba(0, 0, 0, 0.2)'
