'*
'* TESTING...
'*
Function createFilterSortListScreen(item, gridScreen, typeKey=invalid) As Object

    obj = createBasePrefsScreen(GetViewController())
    facade = CreateObject("roGridScreen")
    obj.facade = facade
    obj.facade.Show()
    obj.filterItem = item

    obj.Screen.SetHeader("Filter Options")
    obj.parentscreen = gridScreen

    obj.HandleMessage = prefsFilterHandleMessage
    obj.Activate = prefsFilterSortActivate
    obj.refreshOnActivate = true

    ' other screen options in the filter/sort screen
    obj.createFilterListScreen = createFilterListScreen
    obj.createTypeListScreen = createTypeListScreen

    obj.filterOnClose = true
    obj.forcefilterOnClose = NOT(typeKey=invalid)

    obj.clearFilters = clearFilterList
    obj.getFilterKeyString = getFilterKeyString
    obj.getSortString = getSortString

    ' update and get filter keys
    obj.cacheKeys = getFilterSortCacheKeys(item.server,item.sourceurl,typeKey)
    if obj.cachekeys = invalid then return invalid
    
    filterObj = getFilterParams(item.server,item.sourceurl)
    obj.initialFilterParamsString = filterObj.filterParamsString

    obj.sourceUrl = item.sourceUrl
    obj.server = item.server
    obj.item = item

    ' obtain any filter in place - state saved per session per section
    obj.filterValues = GetGlobal(obj.cachekeys.filterValuesCacheKey)
    print obj.cachekeys.filterValuesCacheKey
    if obj.filterValues = invalid then obj.filterValues = {}

    ' filters - valid for use (cache) for base url
    obj.validFilters = getValidFilters(obj.server,obj.sourceurl)
    if obj.validFilters = invalid or obj.validFilters.count() = 0 then
        Debug("no valid filters found for this section? " + tostr(sectionKey) + "/filters")
        return invalid
    end if   

    obj.defaultTypes = defaultTypes(item.type,obj.cacheKeys.typeKey)
    print obj.cacheKeys.typeKey
    print obj.defaultTypes
    if obj.defaultTypes <> invalid then 
        obj.AddItem({title: "Type",}, "create_type_screen", getDefaultType(obj.defaultTypes))
    end if
    obj.AddItem({title: "Filters"}, "create_filter_screen", obj.getFilterKeyString())
    obj.AddItem({title: "Sorting"}, "create_sort_screen", obj.getSortString())
    obj.AddItem({title: "Clear Filters"}, "clear_filters")
    obj.AddItem({title: "Close"}, "close")

    return obj
End Function

function getDefaultType(types)
    if types <> invalid and types.title <> invalid then return types.title
    return ""
end function

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
    obj.filterValues = obj.parentscreen.filterValues
    obj.cacheKeys = obj.parentscreen.cacheKeys

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


Function createTypeListScreen() As Object
    obj = createBasePrefsScreen(GetViewController())

    obj.Screen.SetHeader("Type Options")
    obj.parentscreen = m

    obj.HandleMessage = prefsFilterHandleMessage
    obj.Activate = prefsFilterSortActivate
    obj.refreshOnActivate = true

    for index = 0 to m.defaultTypes.values.count()-1
        item = m.defaultTypes.values[index]
        if item.key = m.defaultTypes.key then focusedIndex = index
        obj.AddItem({title: item.title, key: item.key}, "filter_type_toggle")
    end for
 
    if focusedIndex <> invalid then obj.screen.SetFocusedListItem(focusedIndex)

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

             if m.callBackItem <> invalid then 
                Debug("filter type changed - recreate the list screen")
                'set the call back before we pop the screen
                callback = m.CallBackItem
                GetViewController().afterCloseCallback = callback
             else if m.filterOnClose = true then 
                GetGlobalAA().AddReplace(m.cachekeys.filterValuesCacheKey,m.filterValues)

                filterObj = getFilterParams(m.server,m.sourceurl)
                dummyObj = {}
                dummyObj.server = m.parentscreen.originalitem.server
                dummyObj.sourceurl = m.parentscreen.originalitem.sourceurl
                dummyObj.getSortString = getSortString                        
                dummyObj.getSortKey = getSortKey
                defaultSort = RegRead("section_sort", "preferences","titleSort:asc")
                sortText = invalid
                if defaultSort <> dummyObj.getSortKey() then sortText = dummyObj.getSortString()

                if (m.initialFilterParamsString <> filterObj.filterParamsString) or m.forcefilterOnClose = true then 
                    Debug("filter options or type changed -- refreshing the grid (new)")
                    ' recreate the grid screen with a call back
                    m.ViewController.PopScreen(m)

                    callback = CreateObject("roAssociativeArray")
                    callback.Item = m.parentscreen.originalitem

                    ' refresh the breadcrumbs
                    if filterObj.hasFilters = true then 
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
                    Debug("filter options and type did not change (sorting may have and will reload if needed)")
                    ' refresh the breadcrumbs
                    if filterObj.hasFilters = true then 
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
            print command
            if command = "close" then
                m.Screen.Close()
            else if command = "clear_filters" then
                m.ClearFilters()
                m.Activate(m)
            else if command = "filter_type_toggle" then
                facade = CreateObject("roGridScreen")
                facade.show()
                
                item = m.contentarray[m.FocusedIndex]

                ' clear any filters
                m.parentscreen.ClearFilters()
                m.screen.close()

                ' recreate the list screen with a callback
                callback = CreateObject("roAssociativeArray")
                callback.Item = m.parentscreen.filterItem
                callback.Item.typeKey = item.key
                callback.breadcrumbs = ["","filter options"]
                callback.facade = facade
                callback.OnAfterClose = createScreenForItemCallback

                ' set the callback and close the list screen
                m.parentscreen.callbackitem = callback
                m.parentscreen.screen.Close()
            else if command = "create_filter_screen" then
                screen = m.createFilterListScreen()
                screen.ScreenName = "Filter Options"
                GetViewController().InitializeOtherScreen(screen, invalid)
                screen.screen.show()
            else if command = "create_type_screen" then
                screen = m.createTypeListScreen()
                screen.ScreenName = "Content Type Options"
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
    GetGlobalAA().AddReplace(m.cachekeys.filterValuesCacheKey,m.filterValues)

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
        else if command = "create_type_screen" then 
            m.AppendValue(index, getDefaultType(m.defaultTypes))
        end if

    end for

End Sub

function getFilterParams(server,sourceUrl)
    ' always pass back a valid object
    obj = {}
    obj.filterParamsString = ""
    obj.filterKeysString = ""
    obj.hasFilters = false
    obj.filterParams = []
    obj.filterKeys = []
    obj.cacheKeys = getFilterSortCachekeys(server,sourceurl)

    if obj.cachekeys = invalid then return obj

    ' obtain any filter in place - state saved per session per section
    obj.filterValues = GetGlobal(obj.cachekeys.filterValuesCacheKey)

    ' type added here - it's not really a filter but will ONLY be changed during the filter process
    if obj.cacheKeys.typeKey <> invalid then
        obj.filterParams.Push("type="+tostr(obj.cacheKeys.typeKey))
    end if

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
    if obj.filterParams.count() = 1 and obj.cacheKeys.typeKey <> invalid then
        obj.hasFilters = false
    end if

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

    ' always clear type - either it will be in the filterParamsString or not..
    re = CreateObject("roRegex", "([\&\?]type=[^\&\?]+)", "i")
    sourceurl = re.ReplaceAll(sourceurl, "")

    ' need a better way to to this... 
    re = CreateObject("roRegex", "/all&", "i")
    sourceurl = re.ReplaceAll(sourceurl, "/all?")

    if filterParamsString = invalid or filterParamsString = "" then return sourceurl
    f = "?"
    if instr(1, sourceurl, "?") > 0 then f = "&"    
    sourceurl = sourceurl + f + filterParamsString

    return sourceurl
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

function createSectionFilterItem(server,sourceurl,itemType)
    sectionKey = getBaseSectionKey(sourceurl)
    imageDir = GetGlobalAA().Lookup("rf_theme_dir")
    filterItem = {}
    filterItem.key = "_section_filters_"
    filterItem.type = itemType
    filterItem.server = server
    filterItem.sourceurl = sourceurl + sectionKey + "/filters"
    filterItem.name = "Filters"
    filterItem.umtitle = "Enabled Filters & Sorting"
    filterItem.title = filterItem.umtitle
    filterItem.viewGroup = "section_filters"
    filterItem.SDPosterURL = imageDir + "gear.png"
    filterItem.HDPosterURL = imageDir + "gear.png"
    rfCDNthumb(filterItem,filterItem.name,invalid)
    print filterItem
    return filterItem
end function


function getValidFilters(server,sourceUrl)
    if server = invalid or sourceUrl = invalid then return invalid

    cacheKeys = getFilterSortCacheKeys(server,sourceurl)
    validFilters = GetGlobal(cacheKeys.filterCacheKey)
    sectionKey = cacheKeys.sectionKey

    if validFilters = invalid then 
        Debug("caching Valid Filters for this section")
        ' set cache to empty ( not invalid -- so we don't keep retrying )
        GetGlobalAA().AddReplace(cacheKeys.filterCacheKey, {})        
        typeKey = "?type="+tostr(cacheKeys.typeKey)
        if cacheKeys.typeKey = invalid then typeKey = ""
        obj = createPlexContainerForUrl(server, "", sectionKey + "/filters" + typeKey)
        if obj <> invalid then 
            ' using an assoc array ( we might want more key/values later )
            GetGlobalAA().AddReplace(cacheKeys.filterCacheKey, obj.getmetadata())        
            validFilters = GetGlobal(cacheKeys.filterCacheKey)
        end if
    end if

    if validFilters = invalid or validFilters.count() = 0 then return invalid
    return validFilters
end function

