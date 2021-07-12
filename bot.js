// Generated by CoffeeScript 2.5.1
var Datastore, PuppetPadlocal, ScanStatus, Wechaty, _, bot, luckdb, sleep, token;

require("dotenv").config();

Datastore = require("nedb-promises");

_ = require("lodash");

luckdb = Datastore.create("./luck.db");

({PuppetPadlocal} = require("wechaty-puppet-padlocal"));

({Wechaty, ScanStatus} = require("wechaty"));

token = process.env.TOKEN;

sleep = function() {
  return new Promise(function(resolve) {
    return setTimeout(resolve, _.random(1.2, 3.2) * 1000);
  });
};

bot = new Wechaty({
  name: "luckybot",
  puppet: new PuppetPadlocal({token})
});

bot.on("scan", function(qrcode, status) {
  if (status === ScanStatus.Waiting && qrcode) {
    return require("qrcode-terminal").generate(qrcode, {
      small: true
    });
  }
}).on("friendship", async function(friendship) {
  var contact;
  await sleep();
  switch (friendship.type()) {
    case bot.Friendship.Type.Receive:
      return (await friendship.accept());
    case bot.Friendship.Type.Confirm:
      contact = friendship.contact();
      return (await contact.say("拉我入群即可进行抽奖活动"));
  }
}).on("room-invite", async function(invitation) {
  await sleep();
  return (await invitation.accept());
}).on("room-join", async function(room, inviteeList) {
  var i, invitee, len, results;
  await sleep();
  results = [];
  for (i = 0, len = inviteeList.length; i < len; i++) {
    invitee = inviteeList[i];
    if (invitee.self()) {
      results.push(room.say("我是抽奖助手， 发送【抽奖】关键字进行活动设置"));
    } else {
      results.push(void 0);
    }
  }
  return results;
}).on("message", async function(message) {
  var exists, luckdoc, members, room, text, texts, winners;
  await sleep();
  if (!message.room()) {
    return;
  }
  if (!message.text()) {
    return;
  }
  if (message.talker().self()) {
    return;
  }
  text = message.text();
  room = message.room();
  if (text === "抽奖") {
    room.say("创建抽奖命令  【抽奖活动|获奖人数|获奖礼品】例如：");
    await sleep();
    room.say("抽奖活动|2人|精美铅笔一支");
  }
  if (text.startsWith("抽奖活动")) {
    exists = (await luckdb.count({
      roomid: room.id,
      status: 0
    }));
    if (exists) {
      return room.say("该群有抽奖活动在进行，群主发送【结束抽奖】强制结束");
    }
    texts = text.split("|");
    if (!(texts.length === 3 && parseInt(texts[1]) > 0)) {
      return room.say("抽奖命令格式错误");
    }
    await luckdb.insert({
      name: texts[2],
      num: parseInt(texts[1]),
      status: 0,
      roomid: room.id,
      members: []
    });
    room.say("抽奖活动创建成功，大家发送【参与抽奖】即可参与");
    room.say("发送【开奖】即可开奖", message.talker());
  }
  if (text === "参与抽奖") {
    luckdoc = (await luckdb.findOne({
      roomid: room.id,
      status: 0
    }));
    if (!luckdoc) {
      return room.say("没有抽奖活动");
    }
    if (luckdoc.members.includes(message.talker().id)) {
      return room.say("您已参与活动", message.talker());
    }
    await luckdb.update({
      _id: luckdoc._id
    }, {
      $push: {
        members: message.talker().id
      }
    });
    return room.say("成功参与抽奖活动", message.talker());
  }
  if (text === "开奖") {
    luckdoc = (await luckdb.findOne({
      roomid: room.id,
      status: 0
    }));
    if (!luckdoc) {
      return room.say("没有抽奖活动");
    }
    members = (await room.memberAll());
    winners = _.sampleSize(luckdoc.members, luckdoc.num);
    winners = winners.map(function(winner) {
      var member;
      member = _.find(members, function(m) {
        return m.id === winner;
      });
      return member;
    });
    return room.say("恭喜获奖者", ...winners);
  }
});

bot.start();
