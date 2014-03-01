'*
'* TESTING...
'*
Function createFilterSortListScreen(item, gridScreen) As Object

    obj = createBasePrefsScreen(GetViewController())
    facade = CreateObject("roGridScreen")
    obj.facade = facade
    obj.facade.Show()

    obj.Screen.SetHeader("Filter Options")
'    obj.parentscreen = GetViewController().screens.peek()
    ' we might call this from a dialog - so we have to pass it
    obj.parentscreen = gridScreen

    obj.HandleMessage = prefsFilterHandleMessage
    obj.Activate = prefsFilterSortActivate
    obj.refreshOnActivate = true

    ' other screen options in the filter/sort screen
    obj.createFilterListScreen = createFilterListScreen

    obj.filterOnClose = true
    obj.clearFilters = clearFilterList
    obj.getFilterKeyString = getFilterKeyString
    obj.getSortString = getSortString

    filterObj = getFilterParams(item.server,item.sourceurl)
    obj.intialFilterParamsString = filterObj.filterParamsString

    obj.sourceUrl = item.sourceUrl
    obj.server = item.server
    obj.item = item

    ' filters - in use for this server/section (saved per session)
    obj.filterCacheKey = getFilterCachekey(item.server,item.sourceurl)
    obj.filterValues = GetGlobal(obj.filterCacheKey)

    if obj.filterValues = invalid then obj.filterValues = {}

    ' filters - valid for use (cache) for base url
    obj.validFilters = getValidFilters(obj.server,obj.sourceurl)
    if obj.validFilters = invalid or obj.validFilters.count() = 0 then
        Debug("no valid filters found for this section? " + tostr(sectionKey) + "/filters")
        return invalid
    end if   

    obj.AddItem({title: "Filters"}, "create_filter_screen", obj.getFilterKeyString())
    obj.AddItem({title: "Sorting"}, "create_sort_screen", obj.getSortString())
    obj.AddItem({title: "Clear Filters"}, "clear_filters")
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

function getSortString()
    sort = getSortingOption(m.server,m.sourceurl)
    sortString = ""
    if sort <> invalid and sort.item <> invalid and sort.item.title <> invalid then 
        sortString = sort.item.title
    end if
    return sortString
end function

function getSortkey()
    sort = getSortingOption(m.server,m.sourceurl)
    sortKey = RegRead("section_sort", "preferences","titleSort:asc")
    if sort <> invalid and sort.item <> invalid and sort.item.key <> invalid then 
        sortKey = sort.item.key
    end if
    return sortKey
end function

function getFilterKeyString()
    filterObj = getFilterParams(m.server,m.sourceurl)
    keyString = ""
    if filterObj <> invalid and filterObj.filterKeysString <> invalid then 
        keyString = filterObj.filterKeysString
    end if
    if keyString = "" then keyString = "None"
    return keyString
end function

Function createFilterListScreen() As Object
    obj = createBasePrefsScreen(GetViewController())

    obj.Screen.SetHeader("Filter Options")
    obj.parentscreen = GetViewController().screens.peek()

    obj.HandleMessage = prefsFilterHandleMessage
    obj.Activate = prefsFilterActivate
    obj.refreshOnActivate = true

    ' other screen options in the filter/sort screen
    obj.createSubFilterListScreen = createSubFilterListScreen

    ' filters - in use for this server/section (saved per session)
    obj.filterCacheKey = obj.parentscreen.filterCacheKey
    obj.filterValues = obj.parentscreen.filterValues

    ' filters - valid for use (cache) for base url
    obj.validFilters = obj.parentscreen.ValidFilters
    if obj.validFilters = invalid or obj.validFilters.count() = 0 then
        Debug("no valid filters found for this section? " + tostr(sectionKey) + "/filters")
        return invalid
    end if   

    for each filter in obj.validFilters
        if obj.filterValues[filter.key] = invalid then 
            obj.filterValues[filter.key] = {}
            obj.filterValues[filter.key].filter = filter
            obj.filterValues[filter.key].values = {}
        end if

        if filter.filtertype = "integer" or filter.filtertype = "string" then 
            obj.AddItem({title: filter.title, key: filter.key, type: filter.filterType}, "filter_toggle",  filterList(obj.filterValues[filter.key]))
        end if

        if filter.filtertype = "boolean" then
            if obj.filterValues[filter.key].title = "true" then 
                obj.filterValues[filter.key].value = 1
            else if obj.filterValues[filter.key].title = "false" then 
                obj.filterValues[filter.key].value = 0
            else 
                obj.filterValues[filter.key].title = ""
                obj.filterValues[filter.key].value = invalid
            end if
            obj.AddItem({title: filter.title, key: filter.key, type: filter.filterType}, "filter_toggle", filterList(obj.filterValues[filter.key]))
        end if
    end for

    obj.AddItem({title: "Close"}, "close")

    return obj
End Function


Function createSubFilterListScreen(key) As Object
    ' instant feedback 
    facade = CreateObject("roGridScreen")
    facade.show()

    obj = createBasePrefsScreen(GetViewController())


    obj.Screen.SetHeader("Sub Filter Options")
    obj.FilterSelection = m.filterValues[key]
    obj.ParentScreen = m

    obj.HandleMessage = prefsFilterHandleMessage

    item = obj.FilterSelection.filter
    container = createPlexContainerForUrl(item.server, "", item.key)
    metadata = container.getmetadata()

    ' parent array
    for each item in metadata
        found = false
        for each key in obj.filterSelection.values
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

    facade.close()
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
    for each key in m.filterValues 
        if tostr(m.filterValues[key].filter.filtertype) = "boolean" then 
            m.filterValues[key].value = invalid
            m.filterValues[key].title = ""
        end if
        m.filterValues[key].values = {}
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
             if m.filterOnClose = true then 
                filterObj = getFilterParams(m.server,m.sourceurl)
                dummyObj = {}
                dummyObj.server = m.parentscreen.originalitem.server
                dummyObj.sourceurl = m.parentscreen.originalitem.sourceurl
                dummyObj.getSortString = getSortString                        
                dummyObj.getSortKey = getSortKey
                defaultSort = RegRead("section_sort", "preferences","titleSort:asc")
                sortText = invalid
                if defaultSort <> dummyObj.getSortKey() then sortText = dummyObj.getSortString()

                if m.intialFilterParamsString <> filterObj.filterParamsString then 
                    ' recreate the grid screen with a call back
                    m.ViewController.PopScreen(m)

                    callback = CreateObject("roAssociativeArray")
                    callback.Item = m.parentscreen.originalitem

                    ' refresh the breadcrumbs
                    if filterObj.hasFIlters = true then 
                         callback.breadcrumbs = [callback.Item.title,"Filters Enabled"]
                    else if sortText <> invalid then 
                         callback.breadcrumbs = [callback.Item.title,sortText]
                    else 
                         callback.breadcrumbs = [firstof(callback.Item.server.name,""),callback.Item.title]
                    end if

                    callback.facade = m.facade
                    callback.OnAfterClose = createScreenForItemCallback

                    GetViewController().afterCloseCallback = callback
                    m.parentscreen.screen.Close()
                    return true

                else 

                    ' refresh the breadcrumbs
                    if filterObj.hasFIlters = true then 
                        m.parentscreen.Screen.SetBreadcrumbText(m.parentscreen.originalitem.title,"Filters Enabled")
                    else if sortText <> invalid then 
                        m.parentscreen.Screen.SetBreadcrumbText(m.parentscreen.originalitem.title, sortText)
                    else 
                        m.parentscreen.Screen.SetBreadcrumbText(firstof(m.parentscreen.originalitem.server.name,""), m.parentscreen.originalitem.title)
                    end if                            

                end if
            end if

            if m.facade <> invalid then m.facade.close()
            m.ViewController.PopScreen(m)

        else if msg.isListItemSelected() then
            m.FocusedIndex = msg.GetIndex()
            command = m.GetSelectedCommand(m.FocusedIndex)
            if command = "close" then
                m.Screen.Close()
            else if command = "clear_filters" then
                m.ClearFilters()
                m.Activate(m)
            else if command = "create_filter_screen" then
                screen = m.createFilterListScreen()
                screen.ScreenName = "Filter Options"
                GetViewController().InitializeOtherScreen(screen, invalid)
                screen.screen.show()
            else if command = "create_sort_screen" then
                ' reuse the same sorting dialog we already have
                dialog = createGridSortingDialog(m,m.parentscreen)
                if dialog <> invalid then dialog.Show(true)
            else if command = "filter_toggle" then
                item = m.contentarray[m.FocusedIndex]
                if item <> invalid then
                    if item.type = "boolean" then 

                        if m.filterValues[item.key].value = invalid then 
                            m.filterValues[item.key].value = 1
                            m.filterValues[item.key].title = "true"
                        else if m.filterValues[item.key].value = 1 then 
                            m.filterValues[item.key].value = 0
                            m.filterValues[item.key].title = "false"
                        else 
                            m.filterValues[item.key].value = invalid 
                            m.filterValues[item.key].title = ""
                        end if
                        
                        m.AppendValue(m.FocusedIndex, m.filterValues[item.key].title)
                    else 
                        screen = m.createSubFilterListScreen(item.key)
                        screen.ScreenName = "Sub Filters"
                        GetViewController().InitializeOtherScreen(screen, invalid)
                        screen.screen.show()
                    end if
    
                end if

            else if command = "sub_filter_toggle" then
                ' filter is toggles
                ' * update the list item value to show it's marked
                ' * add/delete the specific filterValues (m.filterselection.values) depending if it's on/off
                item = m.contentarray[m.FocusedIndex]

                found = false
                for each key in m.filterselection.values
                    if key = item.key then 
                        found = true
                        exit for
                    end if
                end for 

                if found then 
                    filterListDelete(m.filterselection.values, item.key, item.title) 
                    m.AppendValue(m.FocusedIndex, "")
                else 
                    filterListAdd(m.filterselection.values, item.key, item.title) 
                    m.AppendValue(m.FocusedIndex, "X")
                end if
            end if

        end if
    end if

    return handled
End Function


Sub prefsFilterActivate(priorScreen)
    ' save the filters for the session ( per section )
    GetGlobalAA().AddReplace(m.filterCacheKey, m.filterValues)

    for index = 0 to m.contentarray.count()-1
        item = m.contentarray[index]
        if item.key <> invalid and item.type <> invalid then 
           if m.filterValues <> invalid and m.filterValues[item.key] <> invalid then 
               m.AppendValue(index, filterList(m.filterValues[item.key]))
           else 
               m.AppendValue(index, "")
           end if
        end if
    end for
End Sub

Sub prefsFilterSortActivate(priorScreen)

    for index = 0 to m.contentarray.count()-1
        command = m.GetSelectedCommand(index)

        if command = "create_filter_screen" then 
            m.AppendValue(index, m.getFilterKeyString())
        else if command = "create_sort_screen" then 
            m.AppendValue(index, m.getSortString())
        end if

    end for

End Sub

function getFilterParams(server,sourceUrl)
    ' always pass back a valid object
    obj = {}
    obj.sectionKey = getBaseSectionKey(sourceurl)
    obj.filterParamsString = ""
    obj.filterKeysString = ""
    obj.hasFilters = false
    obj.filterParams = []
    obj.filterKeys = []

    if obj.sectionKey = invalid then return obj

    ' obtain any filter in place - state saved per session per section
    obj.filterCacheKey = "filter_inuse_"+tostr(server.machineid)+tostr(obj.sectionKey)
    obj.filterValues = GetGlobal(obj.filterCacheKey)

    for each key in obj.filterValues 
        item = obj.filterValues[key]
        values = ""
        if item.values <> invalid and item.filter <> invalid then 
            if item.filter.filtertype = "boolean" then 
                if item.value <> invalid  then 
                    obj.filterKeys.Push(item.filter.key)
                    obj.filterParams.Push(item.filter.filter + "=" + tostr(item.value))
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
                    obj.filterKeys.Push(item.filter.key)
                    obj.filterParams.Push(item.filter.filter + "=" + tostr(values))
                end if
            end if
        end if
    end for 

    for each param in obj.filterParams
        if obj.filterParamsString = "" then
            obj.filterParamsString = param
        else 
            obj.filterParamsString = obj.filterParamsString + "&" + param
        end if
    end for

    for each key in obj.filterkeys
        title = obj.filterValues[key].filter.title
        if obj.filterkeysString = "" then
            obj.filterkeysString = title
        else 
            obj.filterkeysString = obj.filterkeysString + ", " + title
        end if
    end for

    obj.hasFilters = (obj.filterParams.count() > 0)

    return obj
end function

function addFiltersToUrl(sourceurl,filterObj)
    filterValues = filterObj.filterValues
    filterParamsString = filterObj.filterParamsString

    ' always clear filters before replacing ( or removing all )
    for each key in filterValues
        strip = filterValues[key].filter.filter
        re = CreateObject("roRegex", "([\&\?]"+strip+"=[^\&\?]+)", "i")
        sourceurl = re.ReplaceAll(sourceurl, "")
    end for 

    ' need a better way to to this... 
    re = CreateObject("roRegex", "/all&", "i")
    sourceurl = re.ReplaceAll(sourceurl, "/all?")

    if filterParamsString = invalid or filterParamsString = "" then return sourceurl
    f = "?"
    if instr(1, sourceurl, "?") > 0 then f = "&"    
    sourceurl = sourceurl + f + filterParamsString

    return sourceurl
end function

function getFilterCachekey(server,sourceUrl)
    if server = invalid or sourceUrl = invalid then return invalid

    ' get base section from url
    sectionKey = getBaseSectionKey(sourceUrl)
    if sectionKey = invalid then return invalid

    ' obtain any filter in place - state saved per session per section
    filterCacheKey = "filter_inuse_"+tostr(server.machineid)+tostr(sectionKey)
    return filterCacheKey
end function


function getFilterDescription(server,sourceurl)
    description = ""
    if server = invalid or sourceurl = invalid then return description
    
    dummyObj = {}
    dummyObj.server = server
    dummyObj.sourceurl = sourceurl
    dummyObj.getSortString = getSortString
    sortingText = dummyObj.getSortString()
    filterObj = getFilterParams(dummyObj.server,dummyObj.sourceurl)
    if filterObj <> invalid and filterObj.filterKeysString <> "" then 
        description = "Filters: " + filterObj.filterKeysString
    else 
        description = "Filters: None"
    end if
    if sortingText <> invalid and sortingText <> "" then 
        description = description + chr(10)+chr(10) + "Sort: " + sortingText
    end if

    return Description
end function

' Inline Filtering - refreshes grid on activate -- this is just gross and too many odd issues with filters
' Instead we will close the grid and recreate with a callback
'sub gridFilterSection()
'    Debug("gridFilterSection:: called")
'    grid = m.parentscreen
'
'    if grid = invalid or grid.loader = invalid or grid.loader.sourceurl = invalid or grid.loader.server = invalid then 
'        Debug("gridSortSection:: cannot filter! grid is invalid or requied loader data is missing")
'        return
'    end if
'
'    ' get filter string
'    filterObj = getFilterParams(grid.loader.server,grid.loader.sourceurl)
'
'    sourceurl = grid.loader.sourceurl
'    if sourceurl <> invalid then 
'        sourceurl = addFiltersToUrl(sourceurl,filterObj)
'        grid.loader.sourceurl = sourceurl
'        grid.loader.sortingForceReload = true
'        if grid.loader.listener <> invalid and grid.loader.listener.loader <> invalid then 
'            grid.loader.listener.loader.sourceurl = sourceurl
'            print grid.loader.listener.loader.sourceurl
'        end if
'    end if
'
'    contentArray =  grid.loader.contentArray
'    if contentArray <> invalid and contentArray.count() > 0 then 
'        for index = 0 to contentArray.count()-1
'            if contentArray[index].key <> invalid then 
'                contentArray[index].key = addFiltersToUrl(contentArray[index].key,filterObj)
'                print contentArray[index].key
'            end if
'        end for
'    end if
'
'end sub
'
