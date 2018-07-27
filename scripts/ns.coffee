asci_table = require 'as-table'
parser = require 'xml-js'
moment = require 'moment-timezone'

  
createTable = (res, reismogelijkheden) ->
  table = []
  table.push ['Status', 'Van -> Naar', 'Reistijd', 'Spoor', 'Vertrektijd', "Aankomst", "Overstap", "Vertraging"]

  #res.send JSON.stringify reismogelijkheden
  for reis in reismogelijkheden
    from_to = []
    rail = []
      #res.send JSON.stringify reis.ReisDeel.ReisStop[0].Tijd._text
    arrival = moment(reis.GeplandeAankomstTijd._text).format "LT"  
    departureTime = moment(reis.GeplandeVertrekTijd._text).format "LT"
    delay = if reis.VertrekVertraging isnt undefined then reis.VertrekVertraging._text else 0
    status = reis.Status._text
    #res.send "AantalOverstap #{reis.AantalOverstappen._text}"
    if reis.AantalOverstappen._text is "0" 
      #res.send JSON.stringify reis.ReisDeel
      for stop in reis.ReisDeel.ReisStop
        from_to.push stop.Naam._text
        if stop.Spoor isnt undefined
          rail.push stop.Spoor._text
      rail_text = rail.join '->'
      from_to_text = if from_to.length > 3 then "#{from_to[0]} ... #{from_to[from_to.length - 1]}" else from_to.join '->'
      table.push [status, from_to_text, reis.ActueleReisTijd._text, rail_text, departureTime, arrival, reis.AantalOverstappen._text, delay]
    else
      for reisdeel in reis.ReisDeel
        partial_from_to = []
        partial_rail = []
        for stop in reisdeel.ReisStop
          partial_from_to.push stop.Naam._text
          if stop.Spoor isnt undefined
            partial_rail.push stop.Spoor._text
            
        from_to.push if partial_from_to.length > 3 then "#{partial_from_to[0]} ... #{partial_from_to[partial_from_to.length - 1]}" else partial_from_to.join '->'
        rail.push partial_rail.join '->'
      rail_text = rail.join ', '
      from_to_text = from_to.join ', '
      table.push [status, from_to_text, reis.ActueleReisTijd._text, rail_text, departureTime, arrival, reis.AantalOverstappen._text, delay]
       
  return table

module.exports = (robot) ->
  robot.hear /hi/i, (res) -> 
    res.send "Hi, what can I do for you today?"

  robot.hear /trein van (.*) naar (.*)/i, (res) ->
    from_station = res.match[1]
    to_station = res.match[2]
    date_time = moment().tz("Europe/Amsterdam").add(30,"m").format()

    url = "http://webservices.ns.nl/ns-api-treinplanner?fromStation=#{from_station}&toStation=#{to_station}&dateTime=#{date_time.split('+')[0]}"
    #res.send "Calling service #{url}"
    robot.http(url)
        .header('Accept', 'application/json')
        .header('Authorization', 'BASIC password')
        .get() (err, response, body) ->
          if err
            res.send "Call to get treintijden failed"

          if response.statusCode is 200
            try
              jsonData = parser.xml2json body,{compact:true, spaces:4}
              data = JSON.parse jsonData
            catch error
              res.send "error2: #{error}"

            tableResult = createTable res,data.ReisMogelijkheden.ReisMogelijkheid

            res.send "\n"
            res.send asci_table tableResult
