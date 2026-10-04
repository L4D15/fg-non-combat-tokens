--
-- Non-Combat Tokens
--

DATA_NODE = "noncombattokens";
MENU_SLOT = 3;
MENU_ICON = "radial_sword";

local _fnOriginalTokenDrop = nil;
local _fnOriginalDoubleClickOpen = nil;

function onInit()
	if not Session.IsHost then
		return;
	end

	-- onImageShortcutDrop calls ImageManager.onImageTokenDrop by name, so replace both
	_fnOriginalTokenDrop = ImageManager.onImageTokenDrop;
	ImageManager.unregisterDropCallback("token", _fnOriginalTokenDrop);
	ImageManager.registerDropCallback("token", NonCombatTokens.onImageTokenDrop);
	ImageManager.onImageTokenDrop = NonCombatTokens.onImageTokenDrop;

	_fnOriginalDoubleClickOpen = TokenManager.handleDoubleClickOpen;
	TokenManager.handleDoubleClickOpen = NonCombatTokens.handleDoubleClickOpen;
end

function onTabletopInit()
	if not Session.IsHost then
		return;
	end
	Token.addEventHandler("onAdd", NonCombatTokens.onTokenAdd);
	Token.addEventHandler("onDelete", NonCombatTokens.onTokenDelete);
	Token.addEventHandler("onContainerChanged", NonCombatTokens.onContainerChanged);
	Token.addEventHandler("onMenuSelection", NonCombatTokens.onMenuSelection);
	Token.addEventHandler("onDrop", NonCombatTokens.onTokenDrop);
end

--
--	Token -> record links
--

function findEntry(vContainer, nId)
	if not vContainer or not nId then
		return nil;
	end
	local nodeData = DB.findNode(DATA_NODE);
	if not nodeData then
		return nil;
	end
	local sContainer = (type(vContainer) == "string") and vContainer or DB.getPath(vContainer);
	local sId = tostring(nId);
	for _,v in ipairs(DB.getChildList(nodeData)) do
		if DB.getValue(v, "imagenode", "") == sContainer and DB.getValue(v, "tokenid", "") == sId then
			return v;
		end
	end
	return nil;
end
function getEntry(tokenMap)
	if not tokenMap then
		return nil;
	end
	return NonCombatTokens.findEntry(tokenMap.getContainerNode(), tokenMap.getId());
end
function setEntryToken(nodeEntry, tokenMap)
	DB.setValue(nodeEntry, "imagenode", "string", DB.getPath(tokenMap.getContainerNode()));
	DB.setValue(nodeEntry, "tokenid", "string", tostring(tokenMap.getId()));
end
function addEntry(tokenMap, sClass, sRecord)
	local nodeEntry = DB.createChild(DB.createNode(DATA_NODE));
	if not nodeEntry then
		return nil;
	end
	NonCombatTokens.setEntryToken(nodeEntry, tokenMap);
	DB.setValue(nodeEntry, "link", "windowreference", sClass, sRecord);
	return nodeEntry;
end
function getTokenRecord(tokenMap)
	local nodeEntry = NonCombatTokens.getEntry(tokenMap);
	if not nodeEntry then
		return nil, nil, nil;
	end
	local sClass, sRecord = DB.getValue(nodeEntry, "link", "", "");
	if sClass == "" or sRecord == "" then
		return nil, nil, nodeEntry;
	end
	return sClass, sRecord, nodeEntry;
end

--
--	Drop on image
--

function onImageTokenDrop(cImage, x, y, draginfo)
	if not NonCombatTokens.isNonCombatDrop(draginfo) then
		return _fnOriginalTokenDrop(cImage, x, y, draginfo);
	end

	local sClass, sRecord = draginfo.getShortcutData();
	local nodeRecord = DB.findNode(sRecord);
	x, y = cImage.snapToGrid(x, y);

	local nSpace = ActorCommonManager.getSpaceReach(nodeRecord);
	TokenManager.setDragTokenUnits(nSpace);
	local tokenMap = Token.addToken(cImage.getDatabaseNode(), { asset = draginfo.getTokenData(), x = x, y = y });
	TokenManager.endDragTokenWithUnits();
	if not tokenMap then
		return true;
	end

	NonCombatTokens.addEntry(tokenMap, sClass, sRecord);
	tokenMap.setName(NonCombatTokens.getDisplayName(nodeRecord));
	NonCombatTokens.addMenu(tokenMap);
	return true;
end
-- PCs and combat tracker entries keep the default behavior
function isNonCombatDrop(draginfo)
	if (draginfo.getTokenData() or "") == "" then
		return false;
	end
	local sClass, sRecord = draginfo.getShortcutData();
	if (sClass or "") == "" or (sRecord or "") == "" then
		return false;
	end
	if not DB.findNode(sRecord) then
		return false;
	end
	local sRecordType = ActorManager.getRecordType(sRecord);
	if sRecordType == "" or sRecordType == "charsheet" then
		return false;
	end
	if not CombatRecordManager.hasRecordTypeCallback(sRecordType) then
		return false;
	end
	if CombatManager.getCTFromNode(sRecord) then
		return false;
	end
	return true;
end
function getDisplayName(nodeRecord)
	if DB.getValue(nodeRecord, "isidentified", 1) == 0 then
		local sNonID = DB.getValue(nodeRecord, "nonid_name", "");
		if sNonID ~= "" then
			return sNonID;
		end
	end
	return DB.getValue(nodeRecord, "name", "");
end

--
--	Double click
--

function handleDoubleClickOpen(tokenMap)
	if _fnOriginalDoubleClickOpen(tokenMap) then
		return true;
	end
	local sClass, sRecord = NonCombatTokens.getTokenRecord(tokenMap);
	if not sClass or not DB.findNode(sRecord) then
		return false;
	end
	Interface.openWindow(sClass, sRecord);
	return true;
end

--
--	Token menu
--

function addMenu(tokenMap)
	tokenMap.registerMenuItem(Interface.getString("noncombattokens_menu_addtoct"), MENU_ICON, MENU_SLOT);
end
function onMenuSelection(tokenMap, nSelection, ...)
	if nSelection ~= MENU_SLOT or select("#", ...) > 0 then
		return;
	end
	if not NonCombatTokens.getEntry(tokenMap) then
		return;
	end
	NonCombatTokens.addTokenToCT(tokenMap);
end
-- Returns the new combatant node, or nil.
-- bKeepToken links the existing token instead of replacing it with the CT token.
function addTokenToCT(tokenMap, bKeepToken)
	local sClass, sRecord, nodeEntry = NonCombatTokens.getTokenRecord(tokenMap);
	if not nodeEntry then
		return nil;
	end
	local nodeRecord = sRecord and DB.findNode(sRecord);
	if not nodeRecord then
		ChatManager.SystemMessage(Interface.getString("noncombattokens_error_norecord"));
		return nil;
	end

	-- No tPlacement: the combatant is added without a token, then takes over the existing one
	local tCustom = {
		sClass = sClass,
		sRecord = sRecord,
		nodeRecord = nodeRecord,
		sToken = tokenMap.getPrototype(),
	};
	CombatRecordManager.onRecordTypeEvent(ActorManager.getRecordType(nodeRecord), tCustom);
	if not tCustom.nodeCT then
		ChatManager.SystemMessage(Interface.getString("noncombattokens_error_addfailed"));
		return nil;
	end

	DB.deleteNode(nodeEntry);
	if bKeepToken then
		tokenMap.resetMenuItems();
		TokenManager.linkToken(tCustom.nodeCT, tokenMap);
		TokenManager.updateVisibility(tCustom.nodeCT);
	else
		CombatManager.replaceCombatantToken(tCustom.nodeCT, tokenMap);
	end
	return tCustom.nodeCT;
end

--
--	Token events
--

-- Also fires when an image loads its tokens; menu items do not persist
function onTokenAdd(tokenMap, _)
	if NonCombatTokens.getEntry(tokenMap) then
		NonCombatTokens.addMenu(tokenMap);
	end
end
-- Effects live on combatants: dropping one on a non-combat token adds it to the CT first.
-- Runs after TokenManager.onDrop, which ignores drops on tokens without a combatant.
function onTokenDrop(tokenMap, draginfo)
	if draginfo.getType() ~= "effect" or CombatManager.getCTFromToken(tokenMap) or not NonCombatTokens.getEntry(tokenMap) then
		return;
	end
	local nodeCT = NonCombatTokens.addTokenToCT(tokenMap, true);
	if not nodeCT then
		return true;
	end
	return CombatDropManager.handleAnyDrop(draginfo, DB.getPath(nodeCT));
end
function onTokenDelete(tokenMap)
	local nodeEntry = NonCombatTokens.getEntry(tokenMap);
	if nodeEntry then
		DB.deleteNode(nodeEntry);
	end
end
function onContainerChanged(tokenMap, nodeOldContainer, nOldId)
	local nodeEntry = NonCombatTokens.findEntry(nodeOldContainer, nOldId);
	if not nodeEntry then
		return;
	end
	if tokenMap.getContainerNode() then
		NonCombatTokens.setEntryToken(nodeEntry, tokenMap);
		NonCombatTokens.addMenu(tokenMap);
	else
		DB.deleteNode(nodeEntry);
	end
end
