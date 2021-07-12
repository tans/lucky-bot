require("dotenv").config()
Datastore = require "nedb-promises"
_ = require "lodash"
LuckDB = Datastore.create "./luck.db"

{ PuppetPadlocal } = require "wechaty-puppet-padlocal"
{ Wechaty, ScanStatus } = require "wechaty"

token = process.env.TOKEN

sleep = ->
	new Promise (resolve) ->
		setTimeout resolve, _.random(1.2, 3.2) * 1000

bot = new Wechaty(
	name: "luckybot"
	puppet: new PuppetPadlocal { token }
)

bot
	.on "scan", (qrcode, status) ->
		if status is ScanStatus.Waiting and qrcode
			require("qrcode-terminal").generate qrcode, small: true
	.on "friendship", (friendship) ->
		# 自动通过好友， 并发送拉入群提醒
		await sleep()
		switch friendship.type()
			when bot.Friendship.Type.Receive
				await friendship.accept()

			when bot.Friendship.Type.Confirm
				contact = friendship.contact()
				await contact.say "拉我入群即可进行抽奖活动"
	.on "room-invite", (invitation) ->
		# 自动通过群邀请
		await sleep()
		await invitation.accept()
	.on "room-join", (room, inviteeList) ->
		# 入群自我介绍
		await sleep()
		for invitee in inviteeList
			if invitee.self()
				room.say "我是抽奖助手， 发送【抽奖】关键字进行活动设置"
	.on "message", (message) ->
		# 群抽奖逻辑
		await sleep()
		return unless message.room()
		return unless message.text()
		return if message.talker().self()

		text = message.text()
		room = message.room()

		if text is "抽奖"
			room.say "创建抽奖命令  【抽奖活动|获奖人数|获奖礼品】例如："
			await sleep()
			room.say "抽奖活动|2人|精美铅笔一支"

		if text.startsWith "抽奖活动"
			exists =
				await LuckDB.count
					roomid: room.id
					status: 0
			return room.say(
				"该群有抽奖活动在进行，群主发送【结束抽奖】强制结束"
			) if exists

			texts = text.split "|"
			unless texts.length is 3 and parseInt(texts[1]) > 0
				return room.say "抽奖命令格式错误"
			await LuckDB.insert
				name: texts[2]
				num: parseInt texts[1]
				status: 0
				roomid: room.id
				ownerid: message.talker().id
				members: []

			room.say "抽奖活动创建成功，大家发送【参与抽奖】即可参与"
			room.say "发送【开奖】即可开奖", message.talker()

		if text is "参与抽奖"
			luckdoc =
				await LuckDB.findOne
					roomid: room.id
					status: 0

			return room.say "没有抽奖活动" unless luckdoc

			return room.say "您已参与活动", message.talker() if (
				luckdoc.members.includes message.talker().id
			)

			await LuckDB.update
				_id: luckdoc._id
			,
				$push:
					members: message.talker().id

			return room.say "成功参与抽奖活动", message.talker()

		# if text is '结束抽奖' and

		if text is "开奖"
			luckdoc =
				await LuckDB.findOne
					roomid: room.id
					status: 0
			return room.say "没有抽奖活动" unless luckdoc
			return room.say "非活动发起人无法开奖" unless (
				luckdoc.ownerid is message.talker().id
			)

			members = await room.memberAll()
			winners = _.sampleSize luckdoc.members, luckdoc.num
			winners = winners.map (winner) ->
				member = _.find members, (m) ->
					return m.id == winner
				return member

			room.say "恭喜获奖者, 抽奖活动结束", winners...
			await LuckDB.findOneAndUpdate
				_id: luckdoc._id
			,
				$set:
					status: 1

bot.start()
