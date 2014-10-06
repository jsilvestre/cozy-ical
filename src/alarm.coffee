moment = require 'moment-timezone'
timezones = require './timezones'

module.exports = (Alarm) ->
    {VCalendar, VTodo, VAlarm, VTimezone} = require './index'

    Alarm.getICalCalendar = (name='Cozy Agenda') ->
        calendar = new VCalendar 'Cozy Cloud', name

    Alarm::toIcal = ->
        # Cozy alarms are VAlarm nested in implicit VTodo,
        # with trigg == VTodo.DTSTART ; and VAlarm.trigger == PT0M.

        # Return undefined if mandatory elements miss.

        # If recurrent alarms : timezone = (if @rrule then @timezone else 'GMT')
        timezone = 'GMT' # only UTC.
        try startDate = moment.tz(@trigg, timezone)
        catch e then return undefined

        vtodo = new VTodo startDate, @id, @description

        if @action in ['DISPLAY', 'BOTH']
            vtodo.addAlarm('DISPLAY', @description)

        # if @action in ['EMAIL', 'BOTH']
        #     vtodo.addAlarm('EMAIL', 
        #         "#{@description} #{@details}",
        #         'example@example.com', #TODO : get the user address.
        #         @description)

        # else : ignore other actions.

        vtodo

    Alarm.fromIcal = (vtodo) ->
        alarm = new Alarm()
        alarm.id = vtodo.fields["UID"] if vtodo.fields["UID"]
        alarm.description = vtodo.fields["SUMMARY"] or
                            vtodo.fields["DESCRIPTION"]
        # alarm.details = vtodo.fields["DESCRIPTION"] or
        #                 vtodo.fields["SUMMARY"]
        try alarm.trigg = moment(vtodo.fields['DTSTART'], VAlarm.icalDTUTCFormat).toISOString() # TODO defensive !?
        catch e then return undefined

        valarms = vtodo.subComponents.filter (c) -> c.name is 'VALARM'
        if valarms.length == 0 
            return undefined # Only VTodo with VAlarm can be usefull in cozy.
        else
            actions = valarms.reduce (actions, valarm) -> 
                if 'BOTH' of actions
                    return actions

                if valarm.fields['TRIGGER'] not in ['PT0M', '-PT0M']
                    return actions
                action = valarms.fields['ACTION']

                if action is 'DISPLAY'
                    if 'EMAIL' of actions
                        actions = 'BOTH': true
                    else
                        actions[action] = true
                if action is 'EMAIL'
                    if 'DISPLAY' of actions
                        actions = 'BOTH' : true
                    else actions[action] = true

            , {}
            actions = Object.keys(actions)
            if actions.length is 0
                return undefined

            else alarm.action = actions

        alarm

    Alarm.extractAlarms = (component, timezone) ->
        timezone = 'UTC' unless timezones[timezone]
        alarms = []
        component.walk (component) ->
            if component.name is 'VTODO'
                alarm = Alarm.fromIcal component, timezone
                if alarm? # skip unreadable VTodo.
                    alarms.push alarm 
        alarms