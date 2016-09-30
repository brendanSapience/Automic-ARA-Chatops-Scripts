# Description:
#   ChatOps ARA integration script for hubot, using the REST API for ARA to allow for many useful features
#
# Dependencies:
#   "request" : "^2.74.0"
#   "async" : "^2.0.1"
#   "hubot-auth" : "^1.3.0"
#
# Configuration:
#   HUBOT_ARACHATOPS_USERNAME - the username to use on your installation
#   HUBOT_ARACHATOPS_PASSWORD - the password to use on your installation
#   HUBOT_ARACHATOPS_APIACCESS - the rest api base url
#
# Commands:
#   hubot hello|hi|hey - A command to get you started with the bot
#   hubot get - Help command for all get commands
#   hubot start - Help command for all start commands
#   hubot restart - Help command for all restart commands
#   hubot approval - Help command for all approval related commands
#   hubot set - Help command for all set commands
#   hubot who am i - responds with the internal name of the user
#   hubot subscribe|sub to application|environment|deployment|execution|app|env|dep|exec (<id or name>) - subscribe to application or environment or execution
#   hubot unsubscribe|unsub from application|environment|deployment|execution|app|env|dep|exec <id or name> - unsubscribe from application or environment or execution
#   hubot create package|pack|pak <name> <folder> <type> <application> <components> (<customproperties> <dynamicproperties>) - creates package with parameters. Properties defined in format: <name>=<value>,<name>=<value>...
#
# Notes:
#   The 'approver' role must be given to users by the admin to use approval related commands
#
# Author:
#   Sebastian De Ro

request = require 'request'
http = require 'http'
async = require 'async'
AsyncPolling = require 'async-polling'

module.exports = (robot) ->
  # Load the configuration from env variables
  config =
    username: process.env.HUBOT_ARACHATOPS_USERNAME # ARA username
    password: process.env.HUBOT_ARACHATOPS_PASSWORD # password for the ARA user
    apiAccess: process.env.HUBOT_ARACHATOPS_APIACCESS # base url without / at the end

  config.apiAccess.replace(/\/$/, "") if config.apiAccess # if '/' at url end remove it

  # regex variables and methods
  # if matched using regParam stripQ has to be executed on the string to remove quotes.
  regParam = "(\"[^\"]+\"|'[^']+'|[^\\s]+)" # match param (un)enclosed by quotes
  regBlank = "\\s+" # one or more whitespaces
  regBlankAndParam = regBlank + regParam # combine both for readability in regex strings


  # warn if config is not set
  unless config.username
    robot.logger.warning 'The HUBOT_ARACHATOPS_USERNAME environment variable not set'

  unless config.password
    robot.logger.warning 'The HUBOT_ARACHATOPS_PASSWORD environment variable not set'

  unless config.apiAccess
    robot.logger.warning 'The HUBOT_ARACHATOPS_APIACCESS environment variable not set'


  ############################################################################
  # strip quotes
  #--------------
  # strip quotes from start and end of string(Parameters matched with quotes)
  # If not enclosed param stays the same
  #############################################################################
  stripQ = (stringToStrip) ->
    # replace quote enclosed param with param only.
    return stringToStrip.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1')
  #############################################################################



  ############################################################################
  # verify config
  #--------------
  # verify that config is set
  #--------------
  # returns true if config is set, false if config is not complete
  ############################################################################
  verifyConfig = (msg) ->
    unless config.username
      msg.reply "Seems like no username has been set. Please set the HUBOT_ARACHATOPS_USERNAME environment variable."
      return false

    unless config.password
      msg.reply "Seems like no password has been set. Please set the HUBOT_ARACHATOPS_PASSWORD environment variable."
      return false

    unless config.apiAccess
      msg.reply "Seems like no base REST url has been set. Please set the HUBOT_ARACHATOPS_APIACCESS environment variable."
      return false

    return true
  ############################################################################



  ############################################################################
  # hey
  #----
  # A command to get you started with the bot
  #----
  # hubot hello|hi|hey
  ############################################################################
  robot.respond /(?:Hello|Hi|Hey)\s*$/i, (msg) ->
    message = "Hey, #{msg.envelope.user['name']}!"
    message += "\nLet's get you started with the ARA/ASO ChatOps scripts.\n"

    message += "\n\n\n\n"
    #message += "Debug: test #{config.username}\n"
    message += "*Useful Commands*\n"
    message += "\t*Start Deployment*\n"
    message += "\t\t_#{robot.name} start|do|run execution|deployment|exec|dep for <application name>_\n"
    message += "\t\t_#{robot.name} start|do|run execution|deployment|dep|exec <application> <workflow> <profile> <package> <skip|overwrite>_\n"
    message += "\t*Start Generic Workflow*\n"
    message += "\t\t_#{robot.name} start|do|run generic-workflow|gw <workflow name> - start a generic workflow by name_\n"
    message += "\t*Create Package*\n"
    message += "\t\t_#{robot.name} create package|pack|pak <name> <folder> <type> <application> <components> (<customproperties> <dynamicproperties>)_\n"
    message += "\t\t\t Properties defined in format: <name>=<value>,<name>=<value>...\n"
    message += "\t*Others*\n"
    message += "\t\t_#{robot.name} help_"

    message += "\n\n\n\n"

    message += "*Help Formatting Legend*\n"
    message += "\t*The '|' sign*\n"
    message += "\t\t indicates _options_.\n"
    message += "\t\t Example: _#{robot.name} get applications|apps_ you can choose to *either* use _applications_ or _apps_\n"
    message += "\t*Parentheses '()'*\n"
    message += "\t\t indicates the item is _optional_.\n"
    message += "\t\t Example: _#{robot.name} get applications|apps (like)_ you can choose to use _like_ in your command or not\n"
    message += "\t*Enclosed in Angled-Brackets '<>'*\n"
    message += "\t\t indicates the item is a _parameter_ and should be replaced by a value.\n"
    message += "\t\t Example: _#{robot.name} get applications|apps (like <name filter>)_ in this example _<name filter>_ should be replaced by a value\n"

    message += "\n\t Lets *break down* the following command as an *example*: _'#{robot.name} get applications|apps (like <name filter>)'_\n"
    message += "\t\t Choose to use either _applications_ or _apps_ in your command. Lets choose _apps_. \n"
    message += "\t\t Choose to use _'like <name filter>'_ to filter the name or not. Lets choose to use it. \n"
    message += "\t\t Choose the value to use for _<name filter>_. Lets use _\"Test\"_. \n\n"
    message += "\t\t We end up with the command _'#{robot.name} get apps like \"Test\"'_. \n"

    message += "\n\n\n\n"

    message += "*Detailed Help*\n"
    message += "\tFor more detailed help type the command without it's necessary parameters.\n\n"

    message += "\tExample: _#{robot.name} start|do|run execution|deployment|exec|dep for <application name>_\n"
    message += "\tFor Detailed Help: _#{robot.name} start|do|run execution|deployment|exec|dep for_\n"

    msg.reply message
  ############################################################################

  ############################################################################
  # get
  #---------
  # a workaround to get context help for all get commands
  #---------
  # hubot get
  ############################################################################
  robot.respond /get\s*$/i, (msg) ->
    message = "The get commands are used to display information.\n\n"

    message += "*Applications*\n"
    message += "\t_#{robot.name} get applications|apps (like <name filter>)_\n"
    message += "\t\t Responds with all applications or a list filtered by name\n"
    message += "\t_#{robot.name} get packages|packs|paks for <application name> (like <name filter>)_\n"
    message += "\t\t Packages belonging to the application you specify by it's name. Can be filtered by name.\n"
    message += "\t_#{robot.name} get get workflows|wfs|wf for <application name> (like <name filter>)_\n"
    message += "\t\t Workflows belonging to the application you specify by it's name. Can be filtered by name.\n"

    message += "\n\n\n\n"

    message += "*Environments*\n"
    message += "\t_#{robot.name} get environments|env|nv (like <name filter>)_\n"
    message += "\t\t Responds with all environments or a list filtered by name\n"

    message += "\n\n\n\n"

    message += "*Execution and Deployments*\n"
    message += "\t_#{robot.name} get generic-workflows|gwfs|gws (like <name filter>)_\n"
    message += "\t\t Responds with all generic-workflows or a list filtered by name\n"
    message += "\t_#{robot.name} get execution|deployment|exec|dep report|rep (<id>)_\n"
    message += "\t\t A report of the executions features and status.\n"
    message += "\t\t Can be executed without id to use an id from current context.\n"

    message += "\n\n\n\n"

    message += "*Approvals*\n"
    message += "\t_#{robot.name} get (<type filter>) approvals_\n"
    message += "\t\t Responds with all approvals or a list filtered by type.\n"
    message += "\t\t Allowed types are: approved, rejected, revoked\n"

    msg.reply message
  ############################################################################



  ############################################################################
  # start
  #---------
  # a workaround to get context help for all start commands
  #---------
  # hubot start|do|run
  ############################################################################
  robot.respond /(?:do|start|run)\s*$/i, (msg) ->
    message = "The do, start and run commands are used to start workflows and deployments.\n\n"

    message += "*Deployments*\n"
    message += "\t_#{robot.name} start|do|run execution|deployment|exec|dep for <application name>_\n"
    message += "\t\t This command will start a dialog with the bot to start a deployment.\n"
    message += "\t_#{robot.name} ._\n"
    message += "\t\t This command will start a deployment with given parameters.\n"

    message += "\n\n\n\n"

    message += "*Workflow Executions*\n"
    message += "\t_#{robot.name} start|do|run generic-workflow|gw <workflow name>_\n"
    message += "\t\t This command will start a generic workflow specified by name.\n"

    msg.reply message
  ############################################################################



  ############################################################################
  # restart
  #---------
  # a workaround to get context help for all restart commands
  #---------
  # hubot restart|redo|rerun
  ############################################################################
  robot.respond /(?:redo|restart|rerun)\s*$/i, (msg) ->
    message = "The redo, restart and rerun commands are used to restart workflows and deployments from context.\n\n"

    message += "*Deployments*\n"
    message += "\t_#{robot.name} restart|redo|rerun execution|deployment|exec|dep_\n"
    message += "\t\t Restarts the last deployment started over the bot.\n"

    message += "\n\n\n\n"

    message += "*Workflow Executions*\n"
    message += "\t_#{robot.name} restart|redo|rerun generic-workflow|gw_\n"
    message += "\t\t Restarts the last workflow execution started over the bot.\n"

    msg.reply message
  ############################################################################



  ############################################################################
  # set
  #---------
  # a workaround to get context help for all set commands
  #---------
  # hubot set
  ############################################################################
  robot.respond /set\s*$/i, (msg) ->
    message = "The set commands are used to set properties on packages.\n\n"

    message += "*Properties*\n"
    message += "\t_#{robot.name} set dynamic|dyn property|prop <package id> <property> <value>_\n"
    message += "\t\t Sets the value of a dynamic property for given package id.\n"
    message += "\t_#{robot.name} set custom|cus property|prop <package id> <property> <value>_\n"
    message += "\t\t Sets the value of a custom property for given package id.\n"

    msg.reply message
  ############################################################################



  ############################################################################
  # set
  #---------
  # a workaround to get context help for all set commands
  #---------
  # hubot set
  ############################################################################
  robot.respond /approval(?:s)?(?:\s+requests)?\s*$/i, (msg) ->
    message = "The approval commands are used to approve, reject and revoke approval requests.\n\n"

    message += "*Approval Actions*\n"
    message += "\t_#{robot.name} approve <approval id>_\n"
    message += "\t\t Approves the given approval request.\n"
    message += "\t_#{robot.name} reject <approval id>_\n"
    message += "\t\t Rejects the given approval request.\n"
    message += "\t_#{robot.name} revoke <approval id>_\n"
    message += "\t\t Revokes the given approval request.\n"

    message += "\n\n\n\n"

    message += "*Get Approvals*\n"
    message += "\t_#{robot.name} get (<type filter>) approvals_\n"
    message += "\t\t Responds with all approvals or a list filtered by type.\n"
    message += "\t\t Allowed types are: approved, rejected, revoked\n"

    msg.reply message
  ############################################################################



  ############################################################################
  # who am i
  #---------
  # responds with the internal name of the user to work around the slack adapter
  # not setting the names of chatusers in robot.brain.users
  #---------
  # hubot who am i
  ############################################################################
  robot.respond /who\s+am\s+i/i, (msg) ->
    #get user name from brain using id from envelope. this is to make sure the
    #user can make sure he is using the right value for username since it might not
    #be the same as envelope.user['name'] caused by adapters
    user = robot.brain.userForId(msg.envelope.user['id'])
    msg.reply "You are: #{user['name']}"
  ############################################################################

  # BSP add - Sept 30 2016
  ############################################################################
  # get executions
  #-----------------
  # responds with a list of executions, app name can be filtered
  #-----------------
  # hubot get executions|deployments|runs (for app <name filter>)
  # 
  # PE: would be nice to handle key words like get "last|latest|last n" runs
  ############################################################################
  getAppsRegStr = "get#{regBlank}(?:Executions|Deployments|Runs)"
  getAppsRegStr += "(?:#{regBlank}for#{regBlank}(?:Application|App)#{regBlank}#{regParam})?"
  getAppsReg = new RegExp(getAppsRegStr, 'i')

  robot.respond getAppsReg, (msg) ->
    unless verifyConfig(msg)
      return

    nameFilter = stripQ(msg.match[1]).toLowerCase() if msg.match[1]

    url = "#{config.apiAccess}/executions?max_results=100000"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
		#msg.reply "Something went wrong! check your input.\n\n#{body}"
        return

      if body["total"] is '0'
        msg.reply "I didn't find any deployments or executions!"
        return

      list = "Here are all the executions"
      list += " for application *#{nameFilter}*" if nameFilter
      list += " I found: \n"
      
      for exec in body["data"]
        if not nameFilter or exec["application"]["name"].toLowerCase().match(nameFilter)
          list += "\n Application: #{exec["application"]["name"]} ID:[#{exec["application"]["id"]}]\n"
          list += " Started At: #{exec["actual_from"]} ID:[#{exec["id"]}]\n"
          list += " Status: #{exec["status"]}\n"
          list += " Workflow: #{exec["workflow"]["name"]} ID:[#{exec["workflow"]["id"]}]\n"
          list += " Package: #{exec["package"]["name"]} ID:[#{exec["package"]["id"]}]\n"
          list += " Profile: #{exec["deployment_profile"]["name"]} ID:[#{exec["deployment_profile"]["id"]}]\n"
          list += " Environment: #{exec["deployment_profile"]["environment"]}\n"
          #list += "\n#{exec["id"]}" if not nameFilter or exec["id"].toLowerCase().match(nameFilter)
          #return

      msg.reply list
  ############################################################################



  ############################################################################
  # get applications
  #-----------------
  # responds with a list of applications, name can be filtered
  #-----------------
  # hubot get applications|apps (like <name filter>)
  ############################################################################
  getAppsRegStr = "get#{regBlank}(?:Applications|Apps)"
  getAppsRegStr += "(?:#{regBlank}like#{regBlank}#{regParam})?"
  getAppsReg = new RegExp(getAppsRegStr, 'i')

  robot.respond getAppsReg, (msg) ->
    unless verifyConfig(msg)
      return

    nameFilter = stripQ(msg.match[1]).toLowerCase() if msg.match[1]

    url = "#{config.apiAccess}/applications?max_results=100000"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
		#msg.reply "Something went wrong! check your input.\n\n#{body}"
        return

      if body["total"] is '0'
        msg.reply "I didn't find any applications!"
        return

      list = "Here are all the applications"
      list += " like *#{nameFilter}*" if nameFilter
      list += " I found: \n"

      for app in body["data"]
        list += "\n#{app["name"]}" if not nameFilter or app["name"].toLowerCase().match(nameFilter)

      msg.reply list
  ############################################################################



  ############################################################################
  # get environments
  #-----------------
  # responds with a list of environments, name can be filtered
  #-----------------
  # hubot get environments|env|nv (like <name filter>)
  ############################################################################
  getNvRegStr = "get#{regBlank}(?:environments|env|nv)"
  getNvRegStr += "(?:#{regBlank}like#{regBlankAndParam})?"
  getNvReg = new RegExp(getNvRegStr, 'i')

  robot.respond getNvReg, (msg) ->
    unless verifyConfig(msg)
      return

    nameFilter = stripQ(msg.match[1]).toLowerCase() if msg.match[1]

    url = "#{config.apiAccess}/environments?max_results=100000"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      list = "Here are all the environments"
      list += " like *#{nameFilter}*" if nameFilter
      list += " I found: \n"

      if body["total"] is '0'
        msg.reply "I didn't find any environments!"
        return

      for env in body["data"]
        list += "\n#{env["name"]}" if not nameFilter or env["name"].toLowerCase().match(nameFilter)

      msg.reply list
  ############################################################################



  ############################################################################
  # get generic workflows
  #----------------------
  # responds with a list of generic workflows, name can be filtered
  #----------------------
  # hubot get generic-workflows|gwfs|gws (like <name filter>)
  ############################################################################
  getGwRegStr = "get#{regBlank}(?:generic-workflows|gwfs|gws)"
  getGwRegStr += "(?:#{regBlank}like#{regBlankAndParam})?"
  getGwReg = new RegExp(getGwRegStr, 'i')

  robot.respond getGwReg, (msg) ->
    unless verifyConfig(msg)
      return

    nameFilter = stripQ(msg.match[1]).toLowerCase() if msg.match[1]

    url = "#{config.apiAccess}/workflows?max_results=100000"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      list = "Here are all the generic-workflows"
      list += " like *#{nameFilter}*" if nameFilter
      list += " I found: \n"

      if body["total"] is '0'
        msg.reply "I didn't find any generic-workflows!"
        return

      for wf in body["data"]
        list += "\n#{wf["name"]}" if not nameFilter or wf["name"].toLowerCase().match(nameFilter)

      msg.reply list
  ############################################################################



  ############################################################################
  # get execution report
  #---------------------
  # responds with a report containing information about the deployment
  #---------------------
  # hubot get execution|deployment|exec|dep report|rep (<id>)
  ############################################################################
  getExecRepRegStr = "get#{regBlank}(?:execution|deployment|dep|exec)#{regBlank}(?:report|rep)"
  getExecRepRegStr += "(?:#{regBlank}of#{regBlankAndParam})?"
  getExecRepReg = new RegExp(getExecRepRegStr, 'i')

  robot.respond getExecRepReg, (msg) ->
    unless verifyConfig(msg)
      return

    id = robot.brain.get("executionid") if robot.brain.get("executionid")
    id = stripQ(msg.match[1]) if msg.match[1]

    unless id
      message = "*Description*\n"
      message += "\t This command responds with a report of the executions features and status.\n"
      message += "\t Can be executed without id to use an id from current context.\n\n"

      message += "\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} get execution|deployment|exec|dep report|rep (<id>)_\n"
      message += "\t\t _<id>_ - The execution or deployment id of which you want a report.\n"
      msg.reply message
      return

    url = "#{config.apiAccess}/executions/#{id}"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return
      unless body["status"]
        msg.reply "I didn't find any execution with the id: #{id}"
        return

      report = "Report for execution with id #{id}:\n\n"
      report += "Status: *#{body["status"]}*\n\n" if body["status"]
      report += "Application: #{body["application"]["name"]}\n" if body["application"]
      report += "Workflow: #{body["workflow"]["name"]}\n" if body["workflow"]
      report += "Package: #{body["package"]["name"]}\n" if body["package"]
      report += "Profile: #{body["deployment_profile"]["name"]}\n" if body["deployment_profile"]
      report += "Installmode: #{body["install_mode"]}\n" if body["install_mode"]

      unless body["package"]
        msg.reply report
        return

      # generate package list
      compUrl = "#{config.apiAccess}/packages/#{body["package"]["id"]}/components?max_results=100000"
      request.get {
        uri: compUrl,
        auth: {
          user: config.username,
          pass: config.password
        },
        json : true
      }, (compErr, compR, compBody) ->
        if compBody["error"]
          msg.reply "Something went wrong! check your input.\n\n#{compBody["error"]}"
          return

        if compBody['total']
          report += "\n\nComponents:"

          for comp in compBody['data']
            report += "\n\t#{comp["name"]} (#{comp["custom_type"]["name"]})"

        msg.reply report
  ############################################################################



  ############################################################################
  # get packages
  #-------------
  # responds with a list of packages for a given applicationname, package name can be filtered
  #-------------
  # hubot get packages|packs|paks for <application name> (like <name filter>)
  ############################################################################
  getPakRegStr = "get#{regBlank}(?:packages|packs|paks)"
  getPakRegStr += "(?:#{regBlank}for#{regBlankAndParam}(?:#{regBlank}like#{regBlankAndParam})?)?"
  getPakReg = new RegExp(getPakRegStr, 'i')

  robot.respond getPakReg, (msg) ->
    unless verifyConfig(msg)
      return

    appName = robot.brain.get("appName") if robot.brain.get("appName")
    appName = stripQ(msg.match[1]) if msg.match[1]

    nameFilter = stripQ(msg.match[2]).toLowerCase() if msg.match[2]

    unless appName
      message = "*Description*\n"
      message += "\t This command responds with packages belonging to the application you specify by it's name.\n"
      message += "\t Can be filtered by name.\n\n"

      message += "\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} get packages|packs|paks for <application name> (like <name filter>)_\n"
      message += "\t\t _<application name>_ -The application name of the application you want to get a list of packages from.\n"
      message += "\t\t _<name filter>_ - A case insensitive phrase you want to filter for.\n"
      msg.reply message
      return

    url = "#{config.apiAccess}/packages?max_results=100000&application.name=#{appName}"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return
      unless body["total"]
        msg.reply "I couldn't find any packages for #{appName}"
        return

      list = "Packages for #{appName}"
      list += " like *#{nameFilter}*"if nameFilter
      list += " I managed to find: \n"

      for pak in body['data']
        list += "\n#{pak["name"]}" if not nameFilter or pak["name"].toLowerCase().match(nameFilter)

      msg.reply list
      return
    return
  ############################################################################



  ############################################################################
  # get profiles
  #-------------
  # responds with a list of profiles for a given applicationname, package name can be filtered
  #-------------
  # hubot get profiles|prof|pr for <application name> (like <name filter>)
  ############################################################################
  getProfRegStr = "get#{regBlank}(?:profiles|prof|pr)"
  getProfRegStr += "(?:#{regBlank}for#{regBlankAndParam}(?:#{regBlank}like#{regBlankAndParam})?)?"
  getProfReg = new RegExp(getProfRegStr, 'i')

  robot.respond getProfReg, (msg) ->
    unless verifyConfig(msg)
      return

    appName = robot.brain.get("appName") if robot.brain.get("appName")
    appName = stripQ(msg.match[1]) if msg.match[1]

    nameFilter = stripQ(msg.match[2]).toLowerCase() if msg.match[2]

    unless appName
      message = "*Description*\n"
      message += "\t This command responds with profiles belonging to the application you specify by it's name.\n"
      message += "\t Can be filtered by name.\n\n"

      message += "\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} get profiles|prof|pr for <application name> (like <name filter>)_\n"
      message += "\t\t _<application name>_ -The application name of the application you want to get a list of profiles from.\n"
      message += "\t\t _<name filter>_ - A case insensitive phrase you want to filter for.\n"
      msg.reply message
      return

    url = "#{config.apiAccess}/profiles?max_results=100000&application.name=#{appName}"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return
      unless body["total"]
        msg.reply "I couldn't find any packages for #{appName}"
        return

      list = "Profiles for #{appName}"
      list += " like *#{nameFilter}*"if nameFilter
      list += " I managed to find: \n"

      for prof in body['data']
        list += "\n#{prof["name"]}" if not nameFilter or prof["name"].toLowerCase().match(nameFilter)

      msg.reply list
      return
    return
  ############################################################################



  ############################################################################
  # get workflows
  #--------------
  # responds with a list of workflows for a given application name, workflow name can be filtered
  #--------------
  # hubot get workflows|wfs|wf for <application name> (like <name filter>)
  ############################################################################
  getWfRegStr = "get#{regBlank}(?:workflows|wfs|wf)"
  getWfRegStr += "(?:#{regBlank}for#{regBlankAndParam}(?:#{regBlank}like#{regBlankAndParam})?)?"
  getWfReg = new RegExp(getWfRegStr, 'i')

  robot.respond getWfReg, (msg) ->
    unless verifyConfig(msg)
      return

    appName = robot.brain.get("appName") if robot.brain.get("appName")
    appName = stripQ(msg.match[1]) if msg.match[1]

    nameFilter = stripQ(msg.match[2]).toLowerCase() if msg.match[2]

    unless appName
      message = "*Description*\n"
      message += "\t This command responds with workflows belonging to the application you specify by it's name.\n"
      message += "\t Can be filtered by name.\n\n"

      message += "\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} get workflows|wfs|wf for <application name> (like <name filter>)_\n"
      message += "\t\t _<application name>_ -The application name of the application you want to get a list of packages from.\n"
      message += "\t\t _<name filter>_ - A case insensitive phrase you want to filter for.\n"
      msg.reply message
      return

    url = "#{config.apiAccess}/workflows?max_results=100000&application.name=#{appName}"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return
      unless body["total"]
        msg.reply "I couldn't find any workflows for #{appName}"
        return

      list = "Workflows for #{appName}"
      list += " like *#{nameFilter}*" if nameFilter
      list += " I managed to find: \n"

      for wf in body['data']
        list += "\n#{wf["name"]}" if not nameFilter or wf["name"].toLowerCase().match(nameFilter)

      #send output
      msg.reply list
      return
    return
  ############################################################################



  ############################################################################
  # start execution
  #----------------
  # starts deployment/execution for application
  #----------------
  # hubo execution id is saved in robot.get 'executionid'
  ############################################################################
  restStartExec = (appName, wfName, profileName, packageName, installMode, msg) ->
    # save for persistence
    robot.brain.set 'appName', appName
    robot.brain.set 'wfName', wfName
    robot.brain.set 'profileName', profileName
    robot.brain.set 'packageName', packageName
    robot.brain.set 'installMode', installMode

    url = "#{config.apiAccess}/executions/"
    request.post {
      uri: url,
      auth: { user: config.username, pass: config.password},
      json: true,
      body: {
        application: appName,
        workflow: wfName,
        package: packageName,
        deployment_profile: profileName,
        install_mode: installMode
      }
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      msg.reply "Execution started successfully! ID: *#{body['id']}*"

      robot.brain.set 'executionid', body['id']

      subscribeToDep(body['id'], msg.message.room)# Poll status
      return
    return
  ############################################################################



  ############################################################################
  # workflow
  #---------
  # the workflow part of the do execution dialog
  # arg1 represents an array  containing 'msg' appname and other things that get
  # collected by the dialog
  ############################################################################
  getWfDia = (arg1, callback) ->
    localWf = ""
    response = "Please choose a workflow: \n"

    url = "#{config.apiAccess}/workflows/?application.name=#{arg1.appName}&max_results=100000"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        arg1.msg.reply "Something went wrong! check your input.\n\n" + body["error"]
        return
      unless body['total']
        arg1.msg.reply "Unable to find workflows for this application."
        return

      # build list to check for valid input by checking if input in list
      wfnames = []
      for wf in body['data']
        response += "\n#{wf['name']}"
        wfnames.push wf['name']

      response += "\n\nAnswer using: #{robot.name} workflow|wf|workflow-name <workflow name>"
      arg1.msg.reply response

      wfDiaRegStr = "(?:workflow|wf|workflow-name)#{regBlankAndParam}"
      wfDiaReg = new RegExp(wfDiaRegStr, 'i')
      robot.respond wfDiaReg, (msg) ->
        localWf = stripQ(msg.match[1])
        unless localWf in wfnames
          msg.reply "That workflow is not valid! Please choose a valid one."
          localWf = undefined
          return

        arg1.wfName = localWf
        callback(null, arg1)
  ############################################################################



  ############################################################################
  # profile
  #--------
  # the profile part of the do execution dialog
  # arg1 represents an array  containing 'msg' appname and other things that get
  # collected by the dialog
  ############################################################################
  getProfDia = (arg1, callback) ->
    localProf = ""
    response = "Using workflow: #{arg1.wfName}\n\nPlease choose a profile: \n"

    url = "#{config.apiAccess}/profiles/?application.name=#{arg1.appName}&max_results=100000"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        arg1.msg.reply "Something went wrong! check your input.\n\n#{body2["error"]}"
        return
      if body is undefined or body['total'] is 0
        arg1.msg.reply "Unable to find profiles for this application."
        return

      # build list to check for valid input by checking if input in list
      profileNames = []
      for p in body['data']
        response += "\n" + p['name']
        profileNames.push p['name']

      response += "\n\nAnswer using: #{robot.name} profile|prof|profile-name <profilename>"
      arg1.msg.reply response

      prDiaRegStr = "(?:profile|prof|profile-name)#{regBlankAndParam}"
      prDiaReg = new RegExp(prDiaRegStr, 'i')
      robot.respond prDiaReg, (msg) ->
        localProf = stripQ(msg.match[1])
        unless localProf in profileNames
          msg.reply "That profile is not valid! Please choose a valid one."
          localProf = undefined
          return
        arg1.profileName = localProf
        callback(null, arg1)
  ############################################################################



  ############################################################################
  # package
  #--------
  # the package part of the do execution dialog
  # arg1 represents an array  containing 'msg' appname and other things that get
  # collected by the dialog
  ############################################################################
  getPakDia = (arg1, callback) ->
    localPak = ""
    response = "Using profile: #{arg1.profileName}\n\nPlease choose a package: \n"

    url = "#{config.apiAccess}/packages/?application.name=#{arg1.appName}&max_results=100000"
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body3["error"]}"
        return
      if body is undefined or body['total'] is 0
        arg1.msg.reply "Unable to find packages for this application."
        return

      # build list to check for valid input by checking if input in list
      packageNames = []
      for pk in body['data']
        response += "\n" + pk['name']
        packageNames.push(pk['name'])

      response += "\n\nAnswer using: #{robot.name} package|pak|pkg|package-name <packagename>"
      arg1.msg.reply response

      pakDiaRegStr = "(?:package|pak|package-name)#{regBlankAndParam}"
      pakDiaReg = new RegExp(pakDiaRegStr, 'i')
      robot.respond pakDiaReg, (msg) ->
        localPak = stripQ(msg.match[1])
        unless localPak in packageNames
          msg.reply "That package is not valid! Please choose a valid one."
          localPak = undefined
          return
        arg1.packageName = localPak
        callback(null, arg1)
  ############################################################################



  ############################################################################
  # install mode
  #-------------
  # the install mode part of the do execution dialog
  # arg1 represents an array  containing 'msg' appname and other things that get
  # collected by the dialog
  ############################################################################
  getIMDia = (arg1, callback) ->
    localIM = ""
    response = "Please choose an install mode: \n"
    response += "\nskip"
    response += "\noverwrite"
    response += "\n\n Answer with: #{robot.name} installmode|inmo|instmode <install mode>"
    arg1.msg.reply response

    imDiaRegStr = "(?:installmode|inmo|instmode)#{regBlankAndParam}"
    imDiaReg = new RegExp(imDiaRegStr, 'i')
    robot.respond imDiaReg, (msg) ->
      mode = stripQ(msg.match[1])

      if mode isnt "skip" and mode isnt "overwrite"
        msg.reply "That installmode is not valid! Please choose a valid one."
        return

      localIM = "OverwriteExisting"
      localIM = "SkipExisting" if mode is "skip"

      arg1.installMode = localIM
      callback(null, arg1)
  ############################################################################



  ############################################################################
  # confirmation
  #-------------
  # the confirmation part of the do execution dialog
  # arg1 represents an array  containing 'msg' appname and other things that get
  # collected by the dialog
  ############################################################################
  getConfDia = (arg1, callback) ->
    resp = false

    response = "Data Gathered: \n"
    response += "\nApplication: #{arg1.appName}"
    response += "\nWorkflow: #{arg1.wfName}"
    response += "\nProfile: #{arg1.profileName}"
    response += "\nPackage: #{arg1.packageName}"
    response += "\nInstallmode: #{arg1.installMode}"
    response += "\n\n Do you want me to start the execution? \n\nAnswer with: #{robot.name} yes|no"
    arg1.msg.reply response

    robot.respond /(yes|no)/i, (msg) ->
      resp = true if msg.match[1] and msg.match[1].toLowerCase() is "yes"

      arg1.doExec = resp
      callback(null, arg1)
  ############################################################################



  ############################################################################
  # start execution
  # ---------------
  # starts the do execution dialog
  # Has mandatory parameters because the other do exec function handles inline
  # help without param(s)
  #---------------
  # hubot start|do|run execution|deployment|exec|dep for <application name>
  ############################################################################
  doDepRegStr = "(?:start|do|run)#{regBlank}(?:execution|deployment|dep|exec)"
  doDepRegStr += "#{regBlank}for(?:#{regBlankAndParam})?"
  doDepReg = new RegExp(doDepRegStr, 'i')

  robot.respond doDepReg, (msg) ->
    appName = stripQ(msg.match[1]) if msg.match[1]

    unless appName
      message = "*Description*\n"
      message += "\t This command will start a dialog with the bot to start a deployment.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} start|do|run execution|deployment|exec|dep for <application name>_\n"
      message += "\t\t _<application name>_ -The application name of the application you want to deploy.\n"
      msg.reply message
      return

    # the entry point for the do exec dialog
    async.waterfall([(callback) ->
      arg1 = {}
      arg1.appName = appName
      arg1.msg = msg
      callback(null, arg1)
    , getWfDia, getProfDia, getPakDia, getIMDia, getConfDia], (err, results) ->
      restStartExec(results.appName, results.wfName, results.profileName, results.packageName, results.installMode, msg) if results.doExec
      msg.reply "execution canceled!" unless results.doExec
    )
  ############################################################################



  ############################################################################
  # start execution parameters
  #---------------------------
  # starts execution with parameters
  #---------------------------
  # hubot start|do|run execution|deployment|dep|exec <application> <workflow> <profile> <package> <install mode>
  ############################################################################
  doDepParamRegStr = "(?:start|do|run)#{regBlank}(?:execution|deployment|dep|exec)"
  doDepParamRegStr += "(?:#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam})?"
  doDepParamRegStr += "(?!#{regBlank}for)"
  doDepParamReg = new RegExp(doDepParamRegStr, 'i')

  robot.respond doDepParamReg, (msg) ->
    appName = robot.brain.get('appName') if robot.brain.get('appName')
    appName = stripQ(msg.match[1]) if msg.match[1]
    wfName = robot.brain.get('wfName') if robot.brain.get('wfName')
    wfName = stripQ(msg.match[2]) if msg.match[2]
    profileName = robot.brain.get('profileName') if robot.brain.get('profileName')
    profileName = stripQ(msg.match[3]) if msg.match[3]
    packageName = robot.brain.get('packageName') if robot.brain.get('packageName')
    packageName = stripQ(msg.match[4]) if msg.match[4]
    installMode = robot.brain.get 'installMode' if robot.brain.get('installMode')
    instMode = stripQ(msg.match[5]) if msg.match[5]

    if msg.match[5]
      installMode = "OverwriteExisting"
      installMode = "SkipExisting" if instMode is "skip"

    unless appName and wfName and profileName and packageName and installMode
      message = "*Description*\n"
      message += "\t This command will start a deployment using given parameters.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} start|do|run execution|deployment|dep|exec <application> <workflow> <profile> <package> <skip|overwrite>_\n"
      message += "\t\t _<application>_ - The application name of the application you want to deploy.\n"
      message += "\t\t _<workflow>_ - The workflow to deploy.\n"
      message += "\t\t _<profile>_ - The application profile to use.\n"
      message += "\t\t _<package>_ - The package to use, cannot be empty or it will result in the deployment failing.\n"
      message += "\t\t _<skip|overwrite>_ - The install mode of the deployment. Should overwrite existing or skip existing\n"
      msg.reply message
      return

    restStartExec(appName, wfName, profileName, packageName, installMode, msg)
    return
  ############################################################################



  ############################################################################
  # restart execution
  #------------------
  # restarts an execution using the id from robot.brain
  #------------------
  # hubot restart|redo|rerun execution|deployment|exec|dep
  ############################################################################
  redoDepRegStr = "(?:restart|redo|rerun)#{regBlank}(?:execution|exec|deployment|dep)"
  redoDepReg = new RegExp(redoDepRegStr, 'i')

  robot.respond redoDepReg, (msg) ->
    unless verifyConfig(msg)
      return

    appName = robot.brain.get('appName') if robot.brain.get('appName')
    wfName = robot.brain.get('wfName') if robot.brain.get('wfName')
    profileName = robot.brain.get('profileName') if robot.brain.get('profileName')
    packageName = robot.brain.get('packageName') if robot.brain.get('packageName')
    installMode = robot.brain.get 'installMode' if robot.brain.get('installMode')

    unless appName
      msg.reply "There is no execution to restart."
      return

    restStartExec(appName, wfName, profileName, packageName, installMode, msg)
    return
  ############################################################################



  ############################################################################
  # start generic-workflow
  #-----------------------
  # starts a generic workflow by name
  ############################################################################
  startGenWf = (wfGenName, msg) ->
    robot.brain.set 'wfGenName', wfGenName

    url = config.apiAccess + "/executions/"
    request.post {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json: true,
      body: {
        workflow: wfGenName
      }
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n" + body["error"]
        return

      msg.reply "Execution started successfully! ID: *" + body['id'] + "*"

      robot.brain.set 'executionid', body['id']

  ############################################################################
  # start generic-workflow
  #-----------------------
  # starts a generic workflow by name
  #-----------------------
  # hubot start|do|run generic-workflow|gw <workflow name>
  ############################################################################
  doGwRegStr = "(?:start|do|run)#{regBlank}(?:generic-workflow|gw)"
  doGwRegStr += "(?:#{regBlankAndParam})?"
  doGwReg = new RegExp(doGwRegStr, 'i')

  robot.respond doGwReg, (msg) ->
    unless verifyConfig(msg) #verify configuration before command
      return

    wfGenName = stripQ(msg.match[1]) if msg.match[1]

    unless wfGenName
      message = "*Description*\n"
      message += "\t This command will execute a generic workflow.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} start|do|run generic-workflow|gw <workflow name>_\n"
      message += "\t\t _<workflow name>_ - The workflow name of the generic workflow to execute.\n"
      msg.reply message
      return

    startGenWf(wfGenName, msg)
    return
  ############################################################################



  ############################################################################
  # restart generic-workflow
  #-------------------------
  # restarts a generic workflow using the name from robot.brain
  #-------------------------
  # hubot restart|redo|rerun generic-workflow|gw
  ############################################################################
  redoGwRegStr = "(?:restart|redo|rerun)#{regBlank}(?:generic-workflow|gw)"
  redoGwReg = new RegExp(redoGwRegStr, 'i')

  robot.respond redoGwReg, (msg) ->
    unless verifyConfig(msg) #verify configuration before command
      return

    wfGenName = robot.brain.get('wfGenName') if robot.brain.get('wfGenName')
    unless wfGenName
      msg.reply "There is no generic-workflow to restart."
      return

    startGenWf(wfGenName, msg)
    return
  ############################################################################



  ############################################################################
  # get approvals
  #--------------
  # responds with a list of approvals
  # list can be filtered by approval type
  #--------------
  # hubot get (<type filter>) approvals
  ############################################################################
  getApprRegStr = "get(?:#{regBlankAndParam})?#{regBlank}approvals"
  getApprReg = new RegExp(getApprRegStr, 'i')

  robot.respond getApprReg, (msg) ->
    unless verifyConfig(msg)
      return

    status = stripQ(msg.match[1]) if msg.match[1]

    url = "#{config.apiAccess}/approvals?max_results=100000"
    url += "&status=" + status.charAt(0).toUpperCase() + status.slice(1) if status
    request.get {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n" + body["error"]
        return

      if body["total"] is '0'
        msg.reply "I didn't find any approvals!"
        return

      list = "Here are all the approvals"
      list += " I found: \n"

      for app in body["data"]
        list += "\n ID: " + app["id"] + "\trelated entity id: " + app["related_entity"]['id'] + "\t approval type: " + app["approval_type"] + "\t status: " + app["status"]

      msg.reply list
      return
    return
  ############################################################################



  ############################################################################
  # approve
  #--------
  # approves the given approval request
  #--------
  # hubot approve <approval id>
  ############################################################################
  apprRegStr = "approve(?:#{regBlankAndParam})?"
  apprReg = new RegExp(apprRegStr, 'i')

  robot.respond apprReg, (msg) ->
    unless verifyConfig(msg)
      return

    id = stripQ(msg.match[1]) if msg.match[1]

    unless id
      message = "*Description*\n"
      message += "\t This command will approve a approval request.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} approve <approval id>_\n"
      message += "\t\t _<approval id>_ - The id of the approval request.\n"
      msg.reply message
      return

    # hubot-auth
    unless robot.auth.hasRole(robot.brain.userForName(msg.envelope.user['id']), 'approver')
      msg.reply "Chatuser #{msg.envelope.user['id']} does not have role approver."
      msg.reply robot.brain.rooms
      return

    url = config.apiAccess + "/approvals/#{id}"
    request.post {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true,
      body: {
        status:'Approved',
        comment:"Approval request approved by chatuser:#{msg.envelope.user['name']} with id:'+#{msg.envelope.user['id']} on service:#{robot.adapterName}"
      }
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      msg.reply "New status for #{body['id']}: #{body['status']}"
  ############################################################################



  ############################################################################
  # reject
  #-------
  # rejects the given approval request
  #-------
  # hubot reject <approval id>
  ############################################################################
  rejRegStr = "reject(?:#{regBlankAndParam})?"
  rejReg = new RegExp(rejRegStr, 'i')

  robot.respond rejReg, (msg) ->
    unless verifyConfig(msg)
      return

    id = stripQ(msg.match[1]) if msg.match[1]

    unless id
      message = "*Description*\n"
      message += "\t This command will reject a approval request.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} reject <approval id>_\n"
      message += "\t\t _<approval id>_ - The id of the approval request.\n"
      msg.reply message
      return

    unless robot.auth.hasRole(robot.brain.userForName(msg.envelope.user['id']), 'approver')
      msg.reply "user #{msg.envelope.user['id']} does not have role approver."
      msg.reply robot.brain.rooms
      return

    url = config.apiAccess + "/approvals/#{id}"
    request.post {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true,
      body: {
        status:'Rejected',
        comment:"Approval request rejected by chatuser:#{msg.envelope.user['name']} with id:#{msg.envelope.user['id']} on service:#{robot.adapterName}"
      }
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      msg.reply "New status for #{body['id']}: #{body['status']}"
  ############################################################################



  ############################################################################
  # revoke
  #-------
  # revokes a given approval request
  #-------
  # hubot revoke <approval id>
  ############################################################################
  revRegStr = "revoke(?:#{regBlankAndParam})?"
  revReg = new RegExp(revRegStr, 'i')

  robot.respond revReg, (msg)->
    unless verifyConfig(msg)
      return

    id = stripQ(msg.match[1]) if msg.match[1]

    unless id
      message = "*Description*\n"
      message += "\t This command will revoke a approval request.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} revoke <approval id>_\n"
      message += "\t\t _<approval id>_ - The id of the approval request.\n"
      msg.reply message
      return

    # hubot-auth
    unless robot.auth.hasRole(robot.brain.userForName(msg.envelope.user['id']), 'approver')
      msg.reply "user #{msg.envelope.user['id']} does not have role approver."
      msg.reply robot.brain.rooms
      return

    url = "#{config.apiAccess}/approvals/#{id}"
    request.post {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json : true,
      body: {
        status:'Revoked',
        comment:"Approval request revoked by chatuser:#{msg.envelope.user['name']} with id:#{msg.envelope.user['id']} on service:#{robot.adapterName}"}
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      msg.reply "New status for #{body['id']}: #{body['status']}"
  ############################################################################



  ############################################################################
  # create package
  #---------------
  # creates package with parameters
  # last two parameters are optional
  # properties defined in format: <name>=<value>,<name>=<value>...
  # --------------
  # hubot create package|pack|pak <name> <folder> <type> <application> <components> (<customproperties> <dynamicproperties>)
  ############################################################################
  crPakRegStr = "create#{regBlank}(?:package|pack|pak)"
  crPakRegStr += "(?:"
  crPakRegStr += "#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam}"
  crPakRegStr += "#{regBlankAndParam}?#{regBlankAndParam}?"
  crPakRegStr += ")?"
  crPakReg = new RegExp(crPakRegStr, 'i')

  robot.respond crPakReg, (msg) ->
    name = stripQ(msg.match[1]) if msg.match[1]
    folder = stripQ(msg.match[2]) if msg.match[2]
    type = stripQ(msg.match[3]) if msg.match[3]
    app = stripQ(msg.match[4]) if msg.match[4]
    components = stripQ(msg.match[5]) if msg.match[5]

    unless msg.match[6] and msg.match[6] is "none"
      customproperties = stripQ(msg.match[6]).split(",") if msg.match[6]
    unless msg.match[7] and msg.match[7] is "none"
      dynamicproperties = stripQ(msg.match[7]).split(",") if msg.match[7]

    unless name and folder and type and app and components
      message = "*Description*\n"
      message += "\t This command will create a package and set given properties using parameters.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} create package|pack|pak <name> <folder> <type> <application> <components> (<customproperties> <dynamicproperties>)_\n"
      message += "\t\t _<name>_ - Package name.\n"
      message += "\t\t _<folder>_ - Package folder.\n"
      message += "\t\t _<type>_ - Package customtype.\n"
      message += "\t\t _<application>_ - Package application.\n"
      message += "\t\t _<components>_ - Package components to include. component format: <component>,<component>...\n"
      message += "\t\t _<customproperties>_ - Custom properties and their values to set. property format: <name>=<value>,<name>=<value>...\n"
      message += "\t\t _<dynamicproperties>_ - Dynamic properties and their values to set. property format: <name>=<value>,<name>=<value>...\n"
      msg.reply message
      return

    postdata = "{"
    postdata += "\"name\": \"#{name}\","
    postdata += "\"folder\": \"#{folder}\","
    postdata += "\"custom_type\": \"#{type}\","
    postdata += "\"application\": \"#{app}\""

    unless components is "all"
      comps = components.split(",")
      postdata += ",\"components\": ["
      for comp, i in comps
        postdata += "," if i > 0
        postdata += "\"#{comp}\""
      postdata +="]"

    if customproperties
      postdata += ",\"custom\":{"

      for customproperty, i in customproperties
        valpair = customproperty.split "="
        postdata += "," if i > 0
        postdata += "\"#{valpair[0]}\": \"#{valpair[1]}\""

      postdata += "}"

    if dynamicproperties
      postdata += ",\"dynamic\":{"

      for dynamicproperty, i in dynamicproperties
        valpair = dynamicproperty.split "="
        postdata += "," if i > 0
        postdata += "\"#{valpair[0]}\": \"#{valpair[1]}\""

      postdata += "}"

    postdata += "}"
    msg.reply postdata
    jdata = JSON.parse postdata

    url = "#{config.apiAccess}/packages"
    request.post {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json: true,
      body: jdata
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      msg.reply "Package created. ID:#{body["id"]}"
  ############################################################################



  ############################################################################
  # set dynamic property
  #---------------------
  # Sets a dynamic property of a given package id by
  #---------------------
  # hubot set dynamic|dyn property|prop <package id> <property> <value>
  ############################################################################
  dynPropRegStr = "set#{regBlank}(?:dynamic|dyn)#{regBlank}(?:property|prop)"
  dynPropRegStr += "(?:#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam})?"
  dynPropReg = new RegExp(dynPropRegStr, 'i')

  robot.respond dynPropReg, (msg) ->
    unless verifyConfig(msg)
      return

    id = stripQ(msg.match[1]) if msg.match[1]
    key = stripQ(msg.match[2]) if msg.match[2]
    val = stripQ(msg.match[3]) if msg.match[3]

    postdata = JSON.parse "{\"dynamic\":{\"#{key}\": \"#{val}\"}}"

    unless id and key and val
      message = "*Description*\n"
      message += "\t This command will set the value of a dynamic property for a given package id.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} set dynamic|dyn property|prop <package id> <property> <value>_\n"
      message += "\t\t _<package id>_ - Package id.\n"
      message += "\t\t _<property>_ - Property name.\n"
      message += "\t\t _<value>_ - Property value.\n"

      msg.reply message
      return

    url = "#{config.apiAccess}/packages/#{id}"
    request.post {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json: true,
      body: postdata
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      msg.reply "Property set."
  ############################################################################



  ############################################################################
  # set custom property
  #--------------------
  # Sets a custom property of a given package id by
  #--------------------
  # hubot set custom|cus property|prop <package id> <property> <value>
  ############################################################################
  cusPropRegStr = "set#{regBlank}(?:custom|cus)#{regBlank}(?:property|prop)"
  cusPropRegStr += "(?:#{regBlankAndParam}#{regBlankAndParam}#{regBlankAndParam})?"
  cusPropReg = new RegExp(cusPropRegStr, 'i')

  robot.respond cusPropReg, (msg) ->
    unless verifyConfig(msg)
      return
    id = stripQ(msg.match[1]) if msg.match[1]
    key = stripQ(msg.match[2]) if msg.match[2]
    val = stripQ(msg.match[3]) if msg.match[3]

    postdata = JSON.parse "{\"custom\":{\"#{key}\": \"#{val}\"}}"

    unless id and key and val
      message = "*Description*\n"
      message += "\t This command will set the value of a custom property for a given package id.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} set custom|cus property|prop <package id> <property> <value>_\n"
      message += "\t\t _<package id>_ - Package id.\n"
      message += "\t\t _<property>_ - Property name.\n"
      message += "\t\t _<value>_ - Property value.\n"
      msg.reply message
      return

    url = "#{config.apiAccess}/packages/#{id}"
    request.post {
      uri: url,
      auth: {
        user: config.username,
        pass: config.password
      },
      json: true,
      body: postdata
    }, (err, r, body) ->
      if body["error"]
        msg.reply "Something went wrong! check your input.\n\n#{body["error"]}"
        return

      msg.reply "Property set."
  ############################################################################



  ############################################################################
  # subscribe to deployment
  #------------------------
  # subscribes to deployment status updates
  ############################################################################
  subscribeToDep = (id, channel) ->
    if robot.brain.get("execSubscribed")
      checkforid = robot.brain.get("execSubscribed")
      for cfi in checkforid
        if cfi["id"] is id+"" and cfi["channel"] is channel
          robot.messageRoom "#{channel}", "Already subscribed for this channel"
          return

    robot.messageRoom "#{channel}", "Subscribed to Deployment/Execution *#{id}*"

    if not robot.brain.get("execSubscribed")
      robot.brain.set("execSubscribed", [{
        id: "#{id}",
        channel: "#{channel}"
      }])
    else
      subscr = robot.brain.get("execSubscribed")
      subscr.push({
        id: "#{id}",
        channel: "#{channel}"
      })
      robot.brain.set("execSubscribed", subscr)

    robot.brain.set("execSubhand", []) unless robot.brain.get("execSubhand")
    sl = robot.brain.get("execSubhand")

    laststatus = ""
    endstatuses = ["Finished", "Canceled", "Failed", "Rejected", "Revoked"]

    sl["#{id};#{channel}"] = AsyncPolling( (end) ->
      url = "#{config.apiAccess}/executions/#{id}"
      request.get {
        uri: url,
        auth: {
          user: config.username,
          pass: config.password
        },
        json : true
      }, (err, r, body) ->
        if body["error"]
          msg.reply "Something went wrong! check your input.\n\n" + body["error"]
          return

        if laststatus isnt body["status"]
          robot.messageRoom channel, "Status change for _#{id}_: *#{body['status']}*"

        if body["status"] in endstatuses
          robot.brain.get("execSubhand")["#{id};#{channel}"].stop()

          list = robot.brain.get("execSubscribed")
          for li, index in list
            if li["id"] is id+"" and li["channel"] is channel
              list.splice(index, 1)

          robot.brain.set("execSubscribed", list)

          list = robot.brain.get("execSubhand")
          list.splice("#{id};#{channel}", 1)

          msg.reply "Unsubscribed from *#{id}*."

        laststatus = body["status"]
        end()
    , 1000)

    sl["#{id};#{channel}"].run()

    robot.brain.set("execSubhand", sl)
  ############################################################################



  ############################################################################
  # subscribe to application or environment
  #----------------------------------------
  # subscribes to application or environment updates
  ############################################################################
  subscribeTo = (id, type, channel) ->
    if robot.brain.get("subscribed")
      checkforid = robot.brain.get("subscribed")
      for cfi in checkforid
        if cfi["id"] is id+"" and cfi["channel"] is channel
          robot.messageRoom "#{channel}", "Already subscribed for this channel"
          return

    robot.messageRoom "#{channel}", "Subscribed to #{type} *#{id}*"

    if not robot.brain.get("subscribed")
      robot.brain.set("subscribed", [{
        id: "#{id}",
        channel: "#{channel}",
        type: "#{type}"
      }])
    else
      subscr = robot.brain.get("subscribed")
      subscr.push({
        id: "#{id}",
        channel: "#{channel}",
        type: "#{type}"
      })
      robot.brain.set("subscribed", subscr)

    initAsync = false
    lastid = ""

    robot.brain.set("subhand", []) unless robot.brain.get("subhand")
    sl = robot.brain.get("subhand")

    sl["#{id};#{channel}"] = AsyncPolling( (end) ->
      urlSplit = /(http(?:s?):[\/]{2}.*?)(\/.*)/.exec config.apiAccess
      url = urlSplit[1] + "/ara/api/internal/widget/history/#{id}"
      url += "?mt=#{type}&max_results=100000"
      request.get {
        uri: url,
        auth: {
          user: config.username,
          pass: config.password
        },
        json : true
      }, (err, r, body) ->
        if body["error"]
          msg.reply "Something went wrong! check your input.\n\n" + body["error"]
          return

        if initAsync is true and lastid isnt body["data"][0]["id"]
          for a in body["data"]
            break if a['id'] is lastid

            m = a["message"]
            for mesmatch in m.match(/{.*?}/ig)
              m = m.replace(/{.*?}/i,"'"+m.match(/{"Name":"(.*?)".*?}/i)[1]+"'")

            robot.messageRoom channel, m

        lastid = body["data"][0]["id"]
        initAsync = true
        end()
    , 1000)

    sl["#{id};#{channel}"].run()

    robot.brain.set("subhand", sl)
  ############################################################################



  ############################################################################
  # subscribe to application or environment or execution
  #-----------------------------------------------------
  # Loads subscriptions from env variables and redis brain if set up
  #-----------------------------------------------------
  # hubot subscribe|sub to application|environment|deployment|execution|app|env|dep|exec (<id or name>)
  ############################################################################
  subRegStr = "(?:subscribe|sub)(?:#{regBlank}to#{regBlankAndParam}(?:#{regBlankAndParam})?)?"
  subReg = new RegExp(subRegStr, 'i')
  robot.respond subReg, (msg) ->
    unless verifyConfig(msg)
      return

    typeMatch = stripQ(msg.match[1]).toLowerCase() if msg.match[1]
    type = "Applications" if typeMatch is "application" or typeMatch is "app"
    type = "Environments" if typeMatch is "environment" or typeMatch is "env"
    type = "deployment" if typeMatch is "deployment" or typeMatch is "dep" or typeMatch is "execution" or typeMatch is "exec"

    idOrName = robot.brain.get("executionid") if type and type is "deployment"
    idOrName = stripQ(msg.match[2]) if msg.match[2]

    unless idOrName and type
      message = "*Description*\n"
      message += "\t This command will subscribe to a application or environment change listener, or a deployment status listener.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} subscribe|sub to application|environment|deployment|execution|app|env|dep|exec (<id or name>)_\n"
      message += "\t\t _<id or name>_ - deployment id, application/environment name or id.\n"
      msg.reply message
      return

    if type is "deployment"
      subscribeToDep(idOrName, msg.message.room)
    else
      async.series [
        (callback) ->
          if isNaN(idOrName)
            url = config.apiAccess + "/applications?name=#{idOrName}"
            request.get {
              uri: url,
              auth: {
                user: config.username,
                pass: config.password
              },
              json : true
            }, (err, r, body) ->
              if body["error"]
                msg.reply "Something went wrong! check your input.\n\n" + body["error"]
                return
              unless body["data"]
                msg.reply "Something went wrong! Check your input."
                return

              idOrName = body["data"][0]['id']
              callback(null, "adsf")
          else
            callback(null, "adsf")
        (callback) ->
          subscribeTo(idOrName, type, msg.message.room)
          callback(null, "asdf")
      ]
  ############################################################################



  ############################################################################
  # get subscriptions
  #------------------
  # get and display subscriptions
  #------------------
  # hubot get subscriptions|subs
  ############################################################################
  getSubRegStr = "get#{regBlank}(?:subscriptions|subs)"
  getSubReg = new RegExp(getSubRegStr, 'i')
  robot.respond getSubReg, (msg) ->
    appEnvSubs = robot.brain.get("subscribed") if robot.brain.get("subscribed")
    execSubs = robot.brain.get("execSubscribed") if robot.brain.get("execSubscribed")

    unless appEnvSubs or execSubs
      message = "*Description*\n"
      message += "\t Responds with a list of all subscriptions for this channel or private message channel.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} get subscriptions|subs_\n"
      msg.reply message
      return

    reply = "\n"
    if appEnvSubs
      reply += "*Application or Environment subscriptions*\n"
      for item in appEnvSubs
        reply += "ID: *#{item["id"]}* \tChannel: *#{item["channel"]}*\t Type: *#{item["type"]}*\n"

    if execSubs
      reply += "\n" if appEnvSubs
      reply += "*Execution subscriptions*\n"
      for item in execSubs
        reply += "ID: *#{item["id"]}* \tChannel: *#{item["channel"]}*\n"

    msg.reply reply
  ############################################################################



  ############################################################################
  # unsubscribe
  #------------
  # get and display subscriptions
  #------------
  # hubot unsubscribe|unsub from application|environment|deployment|execution|app|env|dep|exec <id or name>
  ############################################################################
  unsubRegStr = "(?:unsubscribe|unsub)(?:#{regBlank}from#{regBlankAndParam}#{regBlankAndParam})?"
  unsubReg = new RegExp(unsubRegStr, 'i')
  robot.respond unsubReg, (msg) ->
    unless verifyConfig(msg)
      return

    typeMatch = stripQ(msg.match[1]).toLowerCase() if msg.match[1]
    type = "Application" if typeMatch is "application" or typeMatch is "app"
    type = "Environment" if typeMatch is "environment" or typeMatch is "env"
    type = "Deployment" if typeMatch is "deployment" or typeMatch is "dep" or typeMatch is "execution" or typeMatch is "exec"

    idOrName = robot.brain.get("executionid") if type and type is "deployment"
    idOrName = stripQ(msg.match[2]) if msg.match[2]

    unless idOrName and type
      message = "*Description*\n"
      message += "\t This command will unsubscribe from a application or environment change listener, or a deployment status listener.\n"

      message += "\n\n\n\n"

      message += "*Usage*\n"
      message += "\t _#{robot.name} unsubscribe|unsub to application|environment|deployment|execution|app|env|dep|exec (<id or name>)_\n"
      message += "\t\t _<id or name>_ - deployment id, application/environment name or id.\n"
      msg.reply message
      return

    id = idOrName
    async.series [
      (callback) ->
        if isNaN(id)
          url = config.apiAccess + "/applications?name=#{id}"
          request.get {
            uri: url,
            auth: {
              user: config.username,
              pass: config.password
            },
            json : true
          }, (err, r, body) ->
            if body["error"]
              msg.reply "Something went wrong! check your input.\n\n" + body["error"]
              return

            id = body["data"][0]['id']
            callback(null, "asdf")
        else
          callback(null, "asdf")
      (callback) ->
        if type is "Deployment"
          unless robot.brain.get("execSubhand") and robot.brain.get("execSubhand")["#{id};#{msg.message.room}"]
            msg.reply "This channel is not subscribed to #{type} *#{id}*."
            return

          robot.brain.get("execSubhand")["#{id};#{msg.message.room}"].stop()

          list = robot.brain.get("execSubscribed")
          for li, index in list
            if li["id"] is id+"" and li["channel"] is msg.message.room
              list.splice(index, 1)

          robot.brain.set("execSubscribed", list)

          list = robot.brain.get("execSubhand")
          list.splice("#{id};#{msg.message.room}", 1)

          msg.reply "Unsubscribed from *#{id}*."
          callback(null, "asdf")
        else
          unless robot.brain.get("subhand") and robot.brain.get("subhand")["#{id};#{msg.message.room}"]
            msg.reply "This channel is not subscribed to #{type} *#{id}*."
            return

          robot.brain.get("subhand")["#{id};#{msg.message.room}"].stop()

          list = robot.brain.get("subscribed")
          for li, index in list
            if li["id"] is id+"" and li["channel"] is msg.message.room
              list.splice(index, 1)

          robot.brain.set("subscribed", list)

          list = robot.brain.get("subhand")
          list.splice("#{id};#{msg.message.room}", 1)

          msg.reply "Unsubscribed from *#{id}*."
          callback(null, "asdf")
    ]
  ############################################################################



  ############################################################################
  # load subscriptions
  #-------------------
  # Loads subscriptions from env variables and redis brain if set up
  ############################################################################
  # load from brain for applications and environments
  if robot.brain.get("subscribed")
    for item in robot.brain.get("subscribed")
      subscribeTo(item["id"], item["type"], item["channel"])

  # load from brain for deployments
  if robot.brain.get("execSubscribed")
    for item in robot.brain.get("execSubscribed")
      subscribeToDep(item["id"], item["channel"])


  # load from env for applications and environments
  subListFromEnv = process.env.HUBOT_ARASUBSCRIBE_LIST
  if subListFromEnv
    subListSplit = subListFromEnv.split(";")
    for item in subListSplit
      itemSplit = item.split(",")
      unless itemSplit[0]
        break
      subscribeTo(itemSplit[0], itemSplit[1], itemSplit[2])

  # load from env for deployments
  subListFromEnv = process.env.HUBOT_ARASUBSCRIBE_DEPLOYMENTLIST
  if subListFromEnv
    subListSplit = subListFromEnv.split(";")
    for item in subListSplit
      itemSplit = item.split(",")
      unless itemSplit[0]
        break
      subscribeToDep(itemSplit[0], itemSplit[1])
  ############################################################################
