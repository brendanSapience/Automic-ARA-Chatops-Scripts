# Description:
#  Notify bot over REST
#
# Configuration:
#   HUBOT_ARANOTIFY_ROOMS
#
# Commands:
#   hubot get internal room name - returns the room name known to the bot, to be used in the URL of REST notifications
#
# Notes:
#   You can send messages to channels (/notification/<channel>)
#   or you can send messages to selected channels (/notification)
# Author:
#   Sebastian De Ro
module.exports = (robot) ->
  #load rooms from environment variable if set
  rooms = []
  if process.env.HUBOT_ARANOTIFY_ROOMS
    rooms = process.env.HUBOT_ARANOTIFY_ROOMS.split(";")



  ############################################################################
  # notification REST endpoint
  #---------------------------
  # notifies the rooms specified in Environment variable
  #############################################################################
  robot.router.post '/notification', (req, res) ->
    unless rooms
      res.status(400).send 'error: no rooms specified in the configuration'
      return

    for room in rooms
      robot.messageRoom room, req.body.message

    res.status(200).send "notification received, notifying configured rooms"
  #############################################################################



  ############################################################################
  # notification to room REST endpoint
  #-----------------------------------
  # notifies the room specified in the url
  #############################################################################
  robot.router.post '/notification/:room', (req, res) ->
    robot.messageRoom req.params.room, req.body.message
    res.status(200).send "notification received, notifying room"
  #############################################################################



  ############################################################################
  # get internal room name
  #-----------------------
  # returns the room name known to the bot, to be used in the URL
  #-----------------------
  # hubot get internal room name
  #############################################################################
  robot.respond /get internal room name/i, (msg) ->
    msg.reply "Internal room name is: " + msg.message.room
  #############################################################################
