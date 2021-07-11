require("dotenv").config()
Datastore = require "nedb-promises"
_ = require "lodash"
luckdb = Datastore.create "./luck.db"

{PuppetPadlocal} = require "wechaty-puppet-padlocal"
{Wechaty, ScanStatus} = require "wechaty"

token = process.env.TOKEN

bot = new Wechaty(
	name: "luckybot"
	puppet: new PuppetPadlocal { token }
)

bot
	.on "scan", (qrcode, status) ->
		if status is ScanStatus.Waiting and qrcode
			require("qrcode-terminal").generate qrcode, small: true
	.on "friendship", (friendship) ->
		switch friendship.type()
			when bot.Friendship.Type.Receive
				await friendship.accept()

			when bot.Friendship.Type.Confirm
				contact = friendship.contact()
				await contact.say "拉我入群即可进行抽奖活动"
	.on "room-invite", (invitation) ->
		await invitation.accept()
	.on "room-join", (room, inviteeList) ->
		for invitee in inviteeList
			if invitee.self()
				room.say "我是抽奖助手， 发送【抽奖】关键字进行活动设置"
	.on "message", (message) ->
		return unless message.room()
		return unless message.text()
		return if message.talker().self()

		text = message.text()
		room = message.room()

		if text is "抽奖"
			room.say "创建抽奖命令  【抽奖活动|获奖人数|获奖礼品】例如："
			room.say "抽奖活动|2人|精美铅笔一支"

		if text.startsWith "抽奖活动"
			exists =
				await luckdb.count
					roomid: room.id
					status: 0
			return room.say "该群有抽奖活动在进行，群主发送【结束抽奖】强制结束" if exists

			texts = text.split "|"
			unless texts.length is 3 and parseInt(texts[1]) > 0
				return room.say "抽奖命令格式错误"
			await luckdb.insert
				name: texts[2]
				num: parseInt texts[1]
				status: 0
				members: []

			room.say "抽奖活动创建成功，大家发送【参与抽奖】即可参与"
			room.say "发送【开奖】即可开奖", message.talker()

		if text is "参与抽奖"
			luckdoc =
				await luckdb.findOne
					roomid: room.id
					status: 0
			return room.say "没有抽奖活动" unless luckdoc

			return room.say "您已参与活动", message.talker() if (
				luckdoc.members.includes message.talker().id
			)

			await luckdb.update
				_id: luckdoc._id
			,
				$push:
					members: message.talker().id

			return room.say "成功参与抽奖活动", message.talker()

		if text is "开奖"
			luckdoc =
				await luckdb.findOne
					roomid: room.id
					status: 0
			return room.say "没有抽奖活动" unless luckdoc

			members = await room.memberAll()
			winners = _sampleSize luckdoc.members, luckdoc.num
			winners = winners.map (winner) ->
				member = _.find members, (m) ->
					return m.id == winner
				return member

			room.say "恭喜获奖者", winners...

bot.start()
