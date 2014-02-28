'*
'* TESTING...
'*
Function createFilterListScreen(item, parentscreen) As Object
    obj = createBasePrefsScreen(GetViewController())
    obj.Screen.SetHeader("Filter Options")
    obj.parentscreen = GetViewController().screens.peek()

    obj.HandleMessage = prefsFilterHandleMessage
    obj.Activate = prefsFilterActivate
    obj.refreshOnActivate = true
    obj.createSubFilterList = createSubFilterListScreen
    obj.gridFilterSection = gridFilterSection
    obj.filterOnClose = true
    obj.clearFilters = clearFilterList
    ' get base section from url
    sectionKey = getBaseSectionKey(item.sourceurl)
    if sectionKey = invalid then return invalid

    ' obtain any filter in place - state saved per session per section
    obj.filterCacheKey = "filter_inuse_"+tostr(item.server.machineid)+tostr(sectionKey)
    obj.filters = GetGlobal(obj.filterCacheKey)

    if obj.filters = invalid then obj.filters = {}
    test = obj.filters["/library/sections/8/genre"]
    if test <> invalid then print test.values


    ' get valid filters (cache) for base url
    obj.validFilters = getValidFilters(item.server,item.sourceurl)
    

    if obj.validFilters = invalid or obj.validFilters.count() = 0 then
        Debug("no valid filters found for this section? " + tostr(sectionKey) + "/filters")
        return invalid
    end if   

    obj.AddItem({title: "Clear Filters"}, "clear_filters")
    for each filter in obj.validFilters
        if obj.filters[filter.key] = invalid then 
            obj.filters[filter.key] = {}
            obj.filters[filter.key].filter = filter
            obj.filters[filter.key].values = {}
        end if

        if filter.filtertype = "integer" or filter.filtertype = "string" then 
            obj.AddItem({title: filter.title, key: filter.key, type: filter.filterType}, "filter_toggle",  filterList(obj.filters[filter.key]))
        end if

        if filter.filtertype = "boolean" then
            if obj.filters[filter.key].title = "true" then 
                obj.filters[filter.key].value = 1
            else if obj.filters[filter.key].title = "false" then 
                obj.filters[filter.key].value = 0
            else 
                obj.filters[filter.key].title = ""
                obj.filters[filter.key].value = invalid
            end if
            obj.AddItem({title: filter.title, key: filter.key, type: filter.filterType}, "filter_toggle", filterList(obj.filters[filter.key]))
        end if
    end for

    obj.AddItem({title: "Close"}, "close")

    return obj
End Function


Function createSubFilterListScreen(key) As Object
    obj = createBasePrefsScreen(GetViewController())
    obj.Screen.SetHeader("Sub Filter Options")
    obj.FilterSelections = m.filters[key]
    obj.ParentScreen = m

    obj.HandleMessage = prefsFilterHandleMessage
    obj.Activate = prefsSubFilterActivate

    item = obj.FilterSelections.filter
    container = createPlexContainerForUrl(item.server, "", item.key)
    metadata = container.getmetadata()

    ' parent array
    for each item in metadata
        found = false
        for each key in obj.filterSelections.values
            if key = item.key then 
                found = true
            end if
        end for 

        defaultValue = ""
        if found then defaultValue = "X"

        obj.AddItem({title: item.title, key: item.key, metadata: item}, "sub_filter_toggle", defaultValue)
    end for 

    obj.AddItem({title: "Close"}, "close")
    ' obj.AddItem({title: filter.title, key: filter.key, type: filter.filterType}, "boolean", filterList(obj.filters[filter.key]))

    return obj
End Function

function filterList(obj) 
    values = ""
    if obj <> invalid and obj.filter <> invalid then 
        if obj.filter.filtertype = "boolean" then 
            return tostr(obj.title)
        else 
            first = true
            for each key in obj.values
                if values = "" then 
                   values = obj.values[key]
                else 
                   values = values + "," + obj.values[key]
                end if
            end for
        end if
    end if
    return values
end function

function clearfilterList() 
    for each key in m.filters 
        if tostr(m.filters[key].filter.filtertype) = "boolean" then 
            m.filters[key].value = invalid
            m.filters[key].title = ""
        end if
        m.filters[key].values = {}
    end for
end function

sub filterListAdd(values, key, title) 
    values[key] = title
end sub

sub filterListDelete(values, key, title) 
    values.Delete(key)
end sub

Function prefsFilterHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            print "screen closed"
            if m.filterOnClose = true then m.gridFilterSection()
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            m.FocusedIndex = msg.GetIndex()
            command = m.GetSelectedCommand(m.FocusedIndex)
            if command = "close" then
                m.Screen.Close()
            else if command = "clear_filters" then
                m.ClearFilters()
                m.Activate(m)
            else if command = "filter_toggle" then
                item = m.contentarray[m.FocusedIndex]
                if item <> invalid then
                    if item.type = "boolean" then 

                        if m.filters[item.key].value = invalid then 
                            m.filters[item.key].value = 1
                            m.filters[item.key].title = "true"
                        else if m.filters[item.key].value = 1 then 
                            m.filters[item.key].value = 0
                            m.filters[item.key].title = "false"
                        else 
                            m.filters[item.key].value = invalid 
                            m.filters[item.key].title = ""
                        end if
                        
                        m.AppendValue(m.FocusedIndex, m.filters[item.key].title)
                    else 
                        screen = m.createSubFilterList(item.key)
                        screen.ScreenName = "Sub Filters"
'                        screen.parentscreen = m
                        GetViewController().InitializeOtherScreen(screen, invalid)
                        screen.screen.show()
                    end if
    
                end if

            else if command = "sub_filter_toggle" then
                
                ' parent array
                filter = m.parentscreen.contentarray[m.parentscreen.FocusedIndex]
'                filterSelections = m.parentscreen.filters[filter.key]

                ' this value
                item = m.contentarray[m.FocusedIndex]

                found = false
                for each key in m.filterselections.values
                    if key = item.key then 
                        found = true
                    end if
                end for 


                if found then 
                    filterListDelete(m.filterselections.values, item.key, item.title) 
                    m.AppendValue(m.FocusedIndex, "")
                else 
                    filterListAdd(m.filterselections.values, item.key, item.title) 
                    m.AppendValue(m.FocusedIndex, "X")
                end if

            end if

        end if
    end if

    return handled
End Function


Sub prefsFilterActivate(priorScreen)
'        item = m.contentarray[m.FocusedIndex]
'        m.AppendValue(m.FocusedIndex, filterList(m.filters[item.key]))
    for index = 0 to m.contentarray.count()-1
        item = m.contentarray[index]
        if item.key <> invalid and item.type <> invalid then 
           if m.filters <> invalid and m.filters[item.key] <> invalid then 
               m.AppendValue(index, filterList(m.filters[item.key]))
           else 
               m.AppendValue(index, "")
           end if
        end if
    end for
End Sub

Sub prefsSubFilterActivate(priorScreen)
    ' nothing to see here yet
End Sub

sub gridFilterSection()
    grid = m.parentscreen

    if grid = invalid or grid.loader = invalid or grid.loader.sourceurl = invalid or grid.loader.server = invalid then 
        Debug("gridSortSection:: cannot filter! grid is invalid or requied loader data is missing")
        return
    end if

    ' save the filters for the session ( per section )
    GetGlobalAA().AddReplace(m.filterCacheKey, m.filters)

    ' get filter string
    filterObj = getFilterParams(grid.loader.server,grid.loader.sourceurl)

    sourceurl = grid.loader.sourceurl
    if sourceurl <> invalid then 
        sourceurl = addFiltersToUrl(sourceurl,filterObj)
        grid.loader.sourceurl = sourceurl
        grid.loader.sortingForceReload = true
        if grid.loader.listener <> invalid and grid.loader.listener.loader <> invalid then 
            grid.loader.listener.loader.sourceurl = sourceurl
            print grid.loader.listener.loader.sourceurl
        end if
    end if

    contentArray =  grid.loader.contentArray
    if contentArray <> invalid and contentArray.count() > 0 then 
        for index = 0 to contentArray.count()-1
            if contentArray[index].key <> invalid then 
                contentArray[index].key = addFiltersToUrl(contentArray[index].key,filterObj)
                print contentArray[index].key
            end if
        end for
    end if

end sub

function getFilterParams(server,sourceUrl)
    obj = {}
    obj.sectionKey = getBaseSectionKey(sourceurl)
    if obj.sectionKey = invalid then return invalid

    ' obtain any filter in place - state saved per session per section
    obj.filterCacheKey = "filter_inuse_"+tostr(server.machineid)+tostr(obj.sectionKey)
    obj.filters = GetGlobal(obj.filterCacheKey)

    params = []
    for each key in obj.filters 
        item = obj.filters[key]
        values = ""
        if item.values <> invalid and item.filter <> invalid then 
            if item.filter.filtertype = "boolean" then 
                if item.value <> invalid  then 
                    params.Push(item.filter.filter + "=" + tostr(item.value))
                end if
            else 
                first = true
                for each key in item.values
                    if values = "" then 
                       values = key
                    else 
                       values = values + "," + key
                    end if
                end for

                if values <> "" then 
                    params.Push(item.filter.filter + "=" + tostr(values))
                end if
            end if
        end if
    end for 

    filterParams = ""
    for each param in params
        if filterParams = "" then
            filterParams = param
        else 
            filterParams = filterParams + "&" + param
        end if
    end for

    obj.filterParams = filterParams

    return obj
end function

function addFiltersToUrl(sourceurl,filterObj)
    filters = filterObj.filters
    filterParams = filterObj.filterParams

    ' always clear filters before replacing ( or removing all )
    for each key in filters 
        strip = filters[key].filter.filter
        re = CreateObject("roRegex", "([\&\?]"+strip+"=[^\&\?]+)", "i")
        sourceurl = re.ReplaceAll(sourceurl, "")
    end for 

    ' need a better way to to this... 
    re = CreateObject("roRegex", "/all&", "i")
    sourceurl = re.ReplaceAll(sourceurl, "/all?")

    if filterParams = invalid or filterParams = "" then return sourceurl
    f = "?"
    if instr(1, sourceurl, "?") > 0 then f = "&"    
    sourceurl = sourceurl + f + filterParams

    return sourceurl
end function