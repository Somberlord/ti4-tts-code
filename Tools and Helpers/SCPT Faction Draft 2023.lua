--- New faction pool draft style.
-- Authors: SCPT Matt, SCPT Hunter
-- Script: Darrell, Somberlord

-------------------------------------------------------------------------------

function getHelperClient(helperObjectName)
    local function getHelperObject()
        for _, object in ipairs(getAllObjects()) do
            if object.getName() == helperObjectName then return object end
        end
        error('missing object "' .. helperObjectName .. '"')
    end
    local helperObject = false
    local function getCallWrapper(functionName)
        helperObject = helperObject or getHelperObject()
        if not helperObject.getVar(functionName) then error('missing ' .. helperObjectName .. '.' .. functionName) end
        return function(parameters) return helperObject.call(functionName, parameters) end
    end
    return setmetatable({}, { __index = function(t, k) return getCallWrapper(k) end })
end

local function copyTable(t)
    if t and type(t) == 'table' then
        local copy = {}
        for k, v in pairs(t) do
            copy[k] = type(v) == 'table' and copyTable(v) or v
        end
        t = copy
    end
    return t
end

local _buttonHelper = getHelperClient('TI4_BUTTON_HELPER')
local _gameDataHelper = getHelperClient('TI4_GAME_DATA_HELPER')
local _factionHelper = getHelperClient('TI4_FACTION_HELPER')
local _setupHelper = getHelperClient('TI4_SETUP_HELPER')
local _systemHelper = getHelperClient('TI4_SYSTEM_HELPER')
local _zoneHelper = getHelperClient('TI4_ZONE_HELPER')

-------------------------------------------------------------------------------

local PRESET_INPUTS = {
    ['SCPT 2021 Invitation'] = "slices=66,34,47,62,41|29,67,48,22,61|65,69,39,20,80|35,45,26,19,78|73,40,21,60,68|23,63,79,49,37|72,42,59,77,25|64,76,24,46,44&labels=Gravity's Hope's End|Feelin' Lucky Punk?|Intolerable Cruelty|Lump a Coal|Children at Play.|Highway to Meercatol|Gotcha Sumthin|Rigel Rocks",
	['SCPT 2023 Qualifier'] = "slices=21,66,69,40,80|30,63,46,67,61|65,47,59,39,36|35,78,42,26,72|27,23,48,79,62|45,75,24,64,50|31,37,49,25,41&labels=No Country for Hope's End|Vorhallywood|More-d'Or|Lirta IV : The Voyage Home|Synecdoche, New Albion|Three Little Devils|Gravity's Blindside",
	['SCPT 2023 Prelims'] = "slices=63,40,72,46,68|45,64,34,62,49|36,25,24,50,41|48,22,66,79,32|39,61,59,43,71|42,26,73,78,21|47,70,65,44,19&labels=Gone Girl|Big-Lore, Not Four|DOOT DOOT!|Ginger As She Goes|It's Finger...|It's Pronounced Kay All Dree|It's Pronounced Celery",
    --['SCPT 2022 Test'] = "clock=28800&slices=66,34,47,62,41|29,67,48,22,61|65,69,39,20,80|35,45,26,19,78|73,40,21,60,68|23,63,79,49,37|72,42,59,77,25|64,76,24,46,44&labels=Gravity's Hope's End|Feelin' Lucky Punk?|Intolerable Cruelty|Lump a Coal|Children at Play.|Highway to Meercatol|Gotcha Sumthin|Rigel Rocks&factions=sets:SCPT2022",
}

local CHOSEN_SLICES = ""

-- Specify "&factions=sets:SCPT2022" to choose from predefined sets.
local FACTION_SETS = {
    ['SCPT2022'] = {
        "Arborec|Argent|Creuss|Empyrean|Hacan|Jol-Nar|L1Z1X|Letnev",
        "Arborec|Argent|Creuss|Empyrean|Hacan|Jol-Nar|L1Z1X|Letnev",
        "Arborec|Argent|Creuss|Empyrean|Hacan|Jol-Nar|L1Z1X|Letnev",
        "Arborec|Argent|Creuss|Empyrean|Hacan|Jol-Nar|L1Z1X|Letnev",
    }
}

local STARTING_FACTION_POS = {
    {col=0, row=1},
    {col=1, row=0},
    {col=4, row=0},
    {col=1, row=4},
    {col=4, row=4},
}

_config = {
    DEFAULT_SLICES = 7,
    DEFAULT_FACTIONS = 9,

    MIN_SLICES = 6,
    MAX_SLICES = 9,

    MIN_FACTIONS = 6,
    MAX_FACTIONS = 12,
}

_state = false
_lastScale = false

local BUTTONS = {
    {
        id = 'initDraft',
        label = 'Init Draft',
        onClick = 'initDraft',
        tooltip = 'Init SCPT Draft',
		confirm = true
    },
    {
        label = 'Common faction'
    },
    {
        id = 'setupQualifier2023',
        label = 'SCPT 2023\n Qualifiers',
        onClick = 'setupQualifier2023',
        confirm = true,
    },
    {
        id = 'setupPrelim2023',
        label = 'SCPT 2023\n Prelims',
        onClick = 'setupPrelims2023',
    },
    {
        id = 'setupSemi2023',
        label = 'SCPT 2023\n Semis',
    },
    {
        id = 'setupCustom',
        label = 'Setup with\nCustom slices',
        tooltip = 'Setup with custom slices. (right click > input slices)',
        onClick = 'setupCustom',
        confirm = true,
    }
}

local EXTRA_BUTTONS = {
    {
        id = 'drawFaction',
        label = 'Draw Faction',
        onClick = 'drawFaction',
    }
}

local LABEL_COLORS = {
    Color.Red,
    Color.Green,
    Color.Orange,
    Color.Pink,
    Color.Yellow,
    Color.Purple,
    Color.Blue,
    Color.White,
    Color.Teal,
}

-- Expose a function for outside tools to set custom setups.
function setCustomString(customString)
    assert(type(customString) == 'string')
    if not CustomSetup.isInputVisible() then
        CustomSetup.showInput()
    end
    CustomSetup.setInputValue(customString)
end

function onLoad(saveState)
    math.randomseed(os.time())

    _state = {}
    if saveState and string.len(saveState) > 0 then
        _state = JSON.decode(saveState) or _state
    end
    _state.numSlices = _state.numSlices or _config.DEFAULT_SLICES
    _state.numFactions = _state.numFactions or _config.DEFAULT_FACTIONS

    self.clearButtons()
    for i, button in ipairs(BUTTONS) do
        self.createButton({
            click_function = button.onClick or 'doNothing',
            function_owner = self,
            label          = button.label,
            position       = Slots.getPosition(0, i - 1, Slots.DRAFT_MAT),
            rotation       = { x = 0, y = 0, z = 0 },
            scale          = { x = 1, y = 1, z = 1 },
            width          = button.onClick and 1900 or 0,
            height         = button.onClick and 1200 or 0,
            font_size      = 240,
            font_color     = button.onClick and 'Black' or 'White',
            tooltip        = button.tooltip,
        })
        if button.confirm then
            _buttonHelper.addConfirmStep({
                guid = self.getGUID(),
                buttonIndex = i - 1,
                confirm = {
                    label = 'CLICK AGAIN\nTO CONFIRM',
                }
            })
        end
    end

    for i, button in ipairs(EXTRA_BUTTONS) do
        local col_position = 1 + math.floor(i/2)
        local row_position = 2 + ((i-1)%2)
        self.createButton({
            click_function = button.onClick or 'doNothing',
            function_owner = self,
            label          = button.label,
            position       = Slots.getPosition(col_position, row_position, Slots.DRAFT_MAT),
            rotation       = { x = 0, y = 0, z = 0 },
            scale          = { x = 1, y = 1, z = 1 },
            width          = button.onClick and 1900 or 0,
            height         = button.onClick and 1200 or 0,
            font_size      = 240,
            font_color     = button.onClick and 'Black' or 'White',
            tooltip        = button.tooltip,
        })
        if button.confirm then
            _buttonHelper.addConfirmStep({
                guid = self.getGUID(),
                buttonIndex = i - 1,
                confirm = {
                    label = 'CLICK AGAIN\nTO CONFIRM',
                }
            })
        end
    end

    local snapPoints = {}
    local lines = {}
    local color = { r = 1, g = 1, b = 1, a = 0.1 }
    for col = 0, 0 do
        for row = 0, 5 do
            table.insert(lines, Slots.getVectorLine(col, row, Slots.DRAFT_MAT, color))
        end
    end
    for row = 0, 6 do
        for col = 0, 6 do
			if (col == 0 and row == 1) -- common faction
			    or (col > 0 and (
					row < 2 -- 2 first rows
					or row > 3)) -- 2 last rows
			then
				table.insert(snapPoints, {
					position = Slots.getPosition(6 - col, row, Slots.DRAFT_MAT),
					rotation = { x = 0, y = 0, z = 0 },
					rotation_snap = true,
				})
			end
        end
    end
    self.setSnapPoints(snapPoints)
    self.setVectorLines(lines)

    local function lookAtMe(playerColor)
        Player[playerColor].lookAt({
            position = self.getPosition(),
            pitch    = 90,
            yaw      = self.getRotation().y + 180,
            distance = 30
        })
    end
    self.addContextMenuItem('Look at me', lookAtMe)
    self.addContextMenuItem('Input slices', CustomSetup.toggleInput)

end

function onSave()
    return _state and JSON.encode(_state)
end


function _getByName(tag, name)
    for _, object in ipairs(getAllObjects()) do
        if object.tag == tag and object.getName() == name then
            return object
        end
    end
    return false
end


-------------------------------------------------------------------------------

function initDraft()
    startLuaCoroutine(self, 'setupCoroutine')
end

function setupQualifier2023()
	CHOSEN_SLICES = PRESET_INPUTS['SCPT 2023 Qualifier']
    doFinish()
end

function setupPrelims2023()
	CHOSEN_SLICES = PRESET_INPUTS['SCPT 2023 Prelims']
    doFinish()
end

function setupCustom()
	if CustomSetup.isInputVisible() then
		doFinish()
	else 
		broadcastToAll('Enter custom slices before finishing custom Setup', 'Red')
	end
end

function doFinish()
    startLuaCoroutine(self, 'finishCoroutine')
end

function doReset()
    startLuaCoroutine(self, 'resetCoroutine')
end

function drawFaction(obj, player_clicker_color)
    local bag = FactionTokens._getBag()
	bag.shuffle()
    bag.deal(1, player_clicker_color)
end

-------------------------------------------------------------------------------

function setupCoroutine()
    if _getByName('Generic', 'Game Setup Options') or (not _setupHelper.getPoK()) then
        broadcastToAll('Please do setup with PoK enabled first', 'Red')
        return 1
    end
    coroutine.yield(0)

    self.setRotation({ x = 0, y = self.getRotation().y, z = 0 })
    self.setLock(true)

    FactionTokens.stow()
    coroutine.yield(0)


    -- Randomize turns (apply at end).
    local order = {}
    for _, color in ipairs(_zoneHelper.zones()) do
        table.insert(order, color)
    end
    order = assert(VolverMilty.permute(order))

    local factionNames = FactionTokens.randomFactionNames(#STARTING_FACTION_POS)
    local mapString = false


    local positions = Position.startingFactionPositions()
    -- Add draft factions.
    for i, factionName in ipairs(factionNames) do
        FactionTokens.placeToken(factionName, positions[i], self.getRotation(), i==1)
        coroutine.yield(0)
    end
    FactionTokens.dealToAll(2)
    coroutine.yield(0)


    Turns.enable = false
    Turns.type = 2
    Turns.reverse_order = false
    Turns.order = order
    Turns.turn_color = order[1]
    Turns.enable = true
    printToAll('Draft order: ' .. table.concat(order, ', '), 'Yellow')
	
	    -- Start timer.
	_state.clock=28800 -- 8h ?
    if _state.clock then
        assert(type(_state.clock) == 'number')
        local clock = false
        for _, object in ipairs(getAllObjects()) do
            if object.tag == 'Clock' then
                clock = object
            end
        end
        if clock then
            clock.setLock(true)
            clock.Clock.setValue(_state.clock) 
            clock.Clock.pauseStart()
            broadcastToAll('Starting clock', 'Yellow')
        end
    end
    coroutine.yield(0)

    return 1
end

function finishCoroutine()
    if not _setupHelper.getPoK() then
        broadcastToAll('SCPT draft: please do setup with PoK enabled first', 'Red')
        return 1
    end

	local selectedZone = math.random(1, 4)
	local position = PoolZones.getCenter(selectedZone)
	local commonFactionPosition = PoolZones.getCommonFactionPosition()
	local allFactionTokenNames = {}
    for _, object in ipairs(FactionTokens.getAll(true)) do
        local factionTokenName = string.match(object.getName(), '^(.*) Faction Token$')
        table.insert(allFactionTokenNames, factionTokenName)
    end
    coroutine.yield(0)

	local factionList = ""

    for _, object in ipairs(FactionTokens.getAll(true)) do
		local cardName = object.getName()
		local factionName = string.match(cardName, '^(.*) Faction Token*')
        assert(_factionHelper.fromTokenName(factionName))
		local objectPosition = self.positionToLocal(object.getPosition())
		local dist = Vector.distance(objectPosition, position)
		local distCommon = Vector.distance(objectPosition, commonFactionPosition)
		if dist < 5.0 or distCommon < 1.0 then
			printToAll("Chosen Faction : " .. factionName)
			local faction = _factionHelper.fromTokenName(factionName)
			if string.len(factionList) > 0 then factionList = factionList .. '|' end
			factionList = factionList .. faction.tokenName
		end
    end
	
	coroutine.yield(0)
	
	factionList = "&factions=" .. factionList
	local completeUrl = CHOSEN_SLICES .. factionList
	coroutine.yield(0)
	if not CustomSetup.isInputVisible() then
        CustomSetup.showInput()
		CustomSetup.setInputValue(completeUrl)
    else
		local customSlices = CustomSetup.getInputValue()
		completeUrl = customSlices .. factionList
		CustomSetup.setInputValue(completeUrl)
    end
 
	coroutine.yield(0)

	local miltypos = self.getPosition()
	local miltyrot = self.getRotation()

    -- Stow self.
    local toolsBag = _getByName('Bag', 'Tools and Helpers')
    if toolsBag then
        self.setLock(false)
        toolsBag.putObject(self)
    end
	coroutine.yield(0)
	local miltyName = 'Milty Draft Tool'
	local miltyBoard = _getByName('Generic', miltyName)
	local miltySpawned = true
	if miltyBoard then
		miltySpawned = false
	elseif toolsBag then
		for i, entry in ipairs(toolsBag.getObjects()) do
			if entry.name == miltyName then
				miltyBoard = toolsBag.takeObject({
					index             = entry.index,
					position          = miltypos,
					rotation          = miltyrot,
				})
			end
		end
    end
	
	if miltySpawned then
		miltyBoard.setLock(false)
		miltyBoard.setRotation(miltyrot)
		miltyBoard.setLock(true)
	end
	coroutine.yield(0)
	miltyBoard.call('setCustomString',completeUrl)
	coroutine.yield(0)	
	coroutine.yield(0)	
	coroutine.yield(0)	
	coroutine.yield(0)	
	miltyBoard.call('doSetup')


    -- Track game type.
    _gameDataHelper.addExtraData({
        name = 'Scpt2023Draft',
        value = true
    })

    return 1
end



function resetCoroutine()
    resetButtons()
    coroutine.yield(0)

    FactionTokens.stow()
    coroutine.yield(0)


    return 1
end

-------------------------------------------------------------------------------

BoundingBox = {
    _bb = false
}

function BoundingBox.get(object)
    local bounds = object.getBounds()
    return {
        min = {
            x = bounds.center.x - bounds.size.x / 2,
            z = bounds.center.z - bounds.size.z / 2,
        },
        max = {
            x = bounds.center.x + bounds.size.x / 2,
            z = bounds.center.z + bounds.size.z / 2,
        },
    }
end

function BoundingBox.insideWorld(object, bb)
    local p = self.positionToLocal(object.getPosition())
    return p.x > bb.min.x and p.x < bb.max.x and p.z > bb.min.z and p.z < bb.max.z
end


function BoundingBox.inside(object, bb)
    local p = object.getPosition()
    return p.x > bb.min.x and p.x < bb.max.x and p.z > bb.min.z and p.z < bb.max.z
end

function BoundingBox.insideSelf(object)
    BoundingBox._bb = BoundingBox._bb or BoundingBox.get(self)
    return BoundingBox.inside(object, BoundingBox._bb)
end

-------------------------------------------------------------------------------
PoolZones = {
	pools = {{
		x = 1,
		z = -1
	},{
		x = -1,
		z = -1
	},{
		x = 1,
		z = 1
	},{
		x = -1,
		z = 1
	}}
}

function PoolZones.getCommonFactionPosition()
	return Vector(13.6,0.4,-4.8)
end

function PoolZones.getCenter(pool)
	local xOffset = 6.75	-- manual values because maths are hard
	local zOffset = 6.4
	local pool = PoolZones.pools[pool]
	
	local finalPosition = Vector(
		(xOffset * pool.x) - 2.25,
		0.4,
		zOffset * pool.z
	)
	return finalPosition
end
-------------------------------------------------------------------------------

Slots = {
    SIZE = {
        x = 4.04,
        z = 2.70,
        gap = 0.5,
    },
    DRAFT_MAT = {
        numCols = 7,
        numRows = 6
    },
    SELECTION_MAT = {
        numCols = 3,
        numRows = 3
    }
}

function Slots.getPosition(col, row, mat)
    assert(type(col) == 'number' and type(row) == 'number' and type(mat) == 'table')
    assert(type(mat.numCols) == 'number' and type(mat.numRows) == 'number')

    -- Not safe to read bounds while spawning.
    local bounds = {
        x = (mat.numCols * Slots.SIZE.x) + ((mat.numCols + 1) * Slots.SIZE.gap),
        y = 0.4,
        z = (mat.numRows * Slots.SIZE.z) + ((mat.numRows + 1) * Slots.SIZE.gap),
    }

    local p0 = {
        x = -(bounds.x / 2) + Slots.SIZE.gap + (Slots.SIZE.x / 2),
        y = bounds.y + 0.01,
        z = -(bounds.z / 2) + Slots.SIZE.gap + (Slots.SIZE.z / 2),
    }

    return {
        x = p0.x + col * (Slots.SIZE.x + Slots.SIZE.gap),
        y = p0.y,
        z = p0.z + row * (Slots.SIZE.z + Slots.SIZE.gap),
    }
end

function Slots.getVectorLine(col, row, mat, color, rowSpan)
    assert(type(col) == 'number' and type(row) == 'number' and type(mat) == 'table')
    assert(type(mat.numCols) == 'number' and type(mat.numRows) == 'number')

    -- Vector lines have reversed X space?
    local p1 = Slots.getPosition(col, row, mat)
    local p2 = Slots.getPosition(col, row + ((rowSpan or 1) - 1), mat)
    return {
        points = {
            { x = -p1.x, y = p1.y, z = p1.z - Slots.SIZE.z / 2 },
            { x = -p2.x, y = p2.y, z = p2.z + Slots.SIZE.z / 2 },
        },
        rotation = { x = 0, y = 0, z = 0 },
        thickness = Slots.SIZE.x,
        color = color,
        square = true,
        loop = false,
    }
end

-------------------------------------------------------------------------------

-- Mat is 7x6.  COL/ROW in 0-based values:
-- Col 0: buttons.
-- Cols 1-3: slices, offset Z by 0.5.
-- Cols 4-6:
--   Rows 1-4: factions
--   Rows 5-6: seats
Position = {
    SLICE = {
        col0 = 1,
        row0 = 0.5,
        numCols = 3
    },
    FACTION = {
        col0 = 4,
        row0 = 0,
        numCols = 3
    },
    SEAT = {
        col0 = 4,
        row0 = 4,
        numCols = 3
    },
}

function Position._pos(col, row, mat)
    local p = Slots.getPosition(col, row, mat)
    p.x = -p.x  -- x backwards from local?
    p = self.positionToWorld(p)
    p.y = p.y + 3
    return p
end


--- Place common faction
-- @return table : {xyz} position.
function Position.startingFactionPositions()
    local positions = {}
    for _,pos in ipairs(STARTING_FACTION_POS) do
        positions[#positions+1] = Position._pos(pos.col, pos.row, Slots.DRAFT_MAT)
    end
    return positions
end

-------------------------------------------------------------------------------

-- Tile allocation system that ensures players get balanced tile hand.
-- Allocates tiles from three tiers, with minimum and maximum spends for resources/influence.
-- @author Volverbot for design
-- @author Milty for scripting and design
VolverMilty = {

}


function VolverMilty.permute(list)
    assert(type(list) == 'table')
    local shuffled = {}
    for i, v in ipairs(list) do
        local j = math.random(1, #shuffled + 1)
        table.insert(shuffled, j, v)
    end
    return shuffled
end

function VolverMilty.find(target, list) -- find element target's index in list
    for _, v in ipairs(list) do
      if v == target then
        return _
      end
    end
    return nil
end

-------------------------------------------------------------------------------

FactionTokens = {
    BAG_NAME = 'Pick a Faction to Play',
    _bagGuid = false
}

function FactionTokens._getBag()
    local bag = FactionTokens._bagGuid and getObjectFromGUID(FactionTokens._bagGuid)
    if bag then
        return bag
    end
    for _, object in ipairs(getAllObjects()) do
        if object.tag == 'Bag' and object.getName() == FactionTokens.BAG_NAME then
            FactionTokens._bagGuid = object.getGUID()
            return object
        end
    end
    error('FactionTokens._getBag: missing "' .. FactionTokens.BAG_NAME .. '"')
end

function FactionTokens.randomFactionNames(count)
    assert(type(count) == 'number')
    local candidates = {}
    local bag = FactionTokens._getBag()
    for _, entry in ipairs(bag.getObjects()) do
        local factionName = string.match(entry.name, '^(.*) Faction Token*')
        assert(_factionHelper.fromTokenName(factionName))
        table.insert(candidates, factionName)
    end

    local result = {}
    while #result < count do
        local i = math.random(1, #candidates)
        local factionName = table.remove(candidates, i)
        table.insert(result, factionName)
    end
    return result
end

function FactionTokens.dealToAll(numberToDeal)
	local bag = FactionTokens._getBag()
	bag.shuffle()
	for _, color in ipairs(_zoneHelper.zones()) do
		bag.deal(numberToDeal, color)
	end
end

function FactionTokens.placeToken(factionName, position, rotation, hideFaction)
    assert(type(factionName) == 'string')
    assert(type(hideFaction) == 'boolean')
    local faction = assert(_factionHelper.fromTokenName(factionName))
    local factionTokenName = faction.tokenName .. ' Faction Token'

    local finalRotation = rotation
    if(hideFaction) then finalRotation = Vector(rotation.x, rotation.y, 180) end

    local bag = FactionTokens._getBag()
    for i, entry in ipairs(bag.getObjects()) do
        if entry.name == factionTokenName then
            local token = bag.takeObject({
                index             = entry.index,
                position          = position,
                rotation          = finalRotation,
                smooth            = true,
				flip			  = true
            })
            return token
        end
    end
    error('FactionTokens.placeToken: missing token "' .. factionName .. '"')
end

function FactionTokens.getAll(includeInsideSelf)
    assert(type(includeInsideSelf) == 'boolean')
    local nameSet = {}
    for _, faction in pairs(_factionHelper.allFactions(true)) do
        nameSet[faction.tokenName .. ' Faction Token'] = true
    end
    local result = {}
    for _, object in ipairs(getAllObjects()) do
        if object.tag == 'Card' and nameSet[object.getName()] then
            if includeInsideSelf or (not BoundingBox.insideSelf(object)) then
                table.insert(result, object)
            end
        end
    end
    return result
end

function FactionTokens.stow()
    local bag = FactionTokens._getBag()
    for _, object in ipairs(FactionTokens.getAll(true)) do
        bag.putObject(object)
        coroutine.yield(0) -- wait a moment to prevent deck from forming
    end
end

-------------------------------------------------------------------------------

function _selectFaction(color, factionTokenName)
    assert(type(color) == 'string' and type(factionTokenName) == 'string')

    local factionSelector = false
    for _, object in ipairs(getAllObjects()) do
        local name = object.getName()
        if name == 'Faction Selector' then
            local zone = _zoneHelper.zoneFromPosition(object.getPosition())
            if zone == color then
                factionSelector = object
                break
            end
        end
    end
    assert(factionSelector, 'missing faction selector for ' .. color)

    factionSelector.call('selectFaction', factionTokenName)
end

-------------------------------------------------------------------------------

function _onCustomSetupInput()
end

CustomSetup = {}

function CustomSetup.getInputValue(urlArg)
    local index = assert(CustomSetup._getInputIndex())
    local input = assert(self.getInputs()[index + 1]) -- index is 0 based, lua is 1
    local value = assert(input.value)

    -- If using url arg style, extract just the given url arg.
    if urlArg then
        value = string.match(value, urlArg .. '=([^&]*)')
    end

    return value
end

function CustomSetup._getInputIndex()
    for _, input in ipairs(self.getInputs() or {}) do
        if input.input_function == '_onCustomSetupInput' then
            return input.index
        end
    end
end

function CustomSetup.setInputValue(value)
    local index = assert(CustomSetup._getInputIndex())
    local input = assert(self.getInputs()[index + 1]) -- index is 0 based, lua is 1
    input.value = value
    self.editInput(input)
end

function CustomSetup.toggleInput()
    if CustomSetup.isInputVisible() then
        CustomSetup.hideInput()
    else
        CustomSetup.showInput()
    end
end

function CustomSetup.isInputVisible()
    return CustomSetup._getInputIndex() and true or false
end

function CustomSetup.showInput()
    assert(not CustomSetup.isInputVisible())
    local hint = 'Enter slices as "# # # # # | # # # # # | ..." with [left, center, right, left equidistant, far] tile numbers for each slice, then click "setup"'
    self.createInput({
        input_function = '_onCustomSetupInput',
        function_owner = self,
        label          = hint,
        alignment      = 2, -- left
        position       = { x = 0, y = 0.41, z = 0 },
        rotation       = { x = 0, y = 0, z = 0 },
        scale          = { x = 1, y = 1, z = 1 },
        width          = 7000,
        height         = 3500,
        font_size      = 400,
        tooltip        = hint,
        value          = nil, -- Show label as "hint"
    })
end

function CustomSetup.hideInput()
    assert(CustomSetup.isInputVisible())
    local index = assert(CustomSetup._getInputIndex())
    self.removeInput(index)
end

-------------------------------------------------------------------------------
-- Index is only called when the key does not already exist.
local _lockGlobalsMetaTable = {}
function _lockGlobalsMetaTable.__index(table, key)
    error('Accessing missing global "' .. tostring(key or '<nil>') .. '", typo?', 2)
end
function _lockGlobalsMetaTable.__newindex(table, key, value)
    error('Globals are locked, cannot create global variable "' .. tostring(key or '<nil>') .. '"', 2)
end
setmetatable(_G, _lockGlobalsMetaTable)


