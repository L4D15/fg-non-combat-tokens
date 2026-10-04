-- Tests for noncombat_tokens.lua with minimal Fantasy Grounds stubs.

local tNodes = {};
local nNextChild = 0;
local function newNode(sPath)
	local node = { path = sPath, values = {}, children = {} };
	tNodes[sPath] = node;
	return node;
end
DB = {
	findNode = function(s) return tNodes[s]; end,
	createNode = function(s) return tNodes[s] or newNode(s); end,
	createChild = function(node)
		nNextChild = nNextChild + 1;
		local child = newNode(node.path .. ".id-" .. nNextChild);
		child.parent = node;
		table.insert(node.children, child);
		return child;
	end,
	getChildList = function(node) local t = {}; for i,v in ipairs(node.children) do t[i] = v; end return t; end,
	getPath = function(node) return node.path; end,
	getValue = function(node, sField, ...)
		local v = node.values[sField];
		if v == nil then return ...; end
		if type(v) == "table" then return v[1], v[2]; end
		return v;
	end,
	setValue = function(node, sField, sType, v1, v2)
		node.values[sField] = (sType == "windowreference") and { v1, v2 } or v1;
	end,
	deleteNode = function(node)
		tNodes[node.path] = nil;
		if node.parent then
			for i,v in ipairs(node.parent.children) do
				if v == node then table.remove(node.parent.children, i); break; end
			end
		end
	end,
};

local tHandlers = {};
local tTokens = {};
local nNextToken = 0;
local function fire(sEvent, ...)
	for _,fn in ipairs(tHandlers[sEvent] or {}) do fn(...); end
end
local function newToken(nodeContainer, tAdd)
	nNextToken = nNextToken + 1;
	local token = { id = nNextToken, container = nodeContainer, asset = tAdd.asset, x = tAdd.x, y = tAdd.y, menu = {} };
	token.getContainerNode = function() return token.container; end
	token.getId = function() return token.id; end
	token.getPrototype = function() return token.asset; end
	token.getPosition = function() return token.x, token.y; end
	token.getOrientation = function() return 0; end
	token.setOrientation = function() end
	token.setName = function(s) token.name = s; end
	token.registerMenuItem = function(sLabel, sIcon, nSlot) token.menu[nSlot] = sLabel; end
	token.delete = function() tTokens[token.id] = nil; fire("onDelete", token); end
	tTokens[token.id] = token;
	fire("onAdd", token, false);
	return token;
end
Token = {
	addEventHandler = function(sEvent, fn) tHandlers[sEvent] = tHandlers[sEvent] or {}; table.insert(tHandlers[sEvent], fn); end,
	addToken = function(nodeContainer, tAdd) return newToken(nodeContainer, tAdd); end,
};

Session = { IsHost = true };
local tStrings = {};
Interface = {
	getString = function(s) return s; end,
	openWindow = function(sClass, sRecord) Interface.opened = { sClass, sRecord }; return {}; end,
};
ChatManager = { SystemMessage = function(s) table.insert(tStrings, s); end };

local tDropCallbacks = {};
local function origTokenDrop() ImageManagerOrigCalled = true; return true; end
ImageManager = {
	onImageTokenDrop = origTokenDrop,
	registerDropCallback = function(sType, fn) tDropCallbacks[sType] = fn; end,
	unregisterDropCallback = function(sType, fn) if tDropCallbacks[sType] == fn then tDropCallbacks[sType] = nil; end end,
};
TokenManager = {
	handleDoubleClickOpen = function(tokenMap) return tokenMap.inCT == true; end,
	setDragTokenUnits = function(n) TokenManager.units = n; end,
	endDragTokenWithUnits = function() TokenManager.units = nil; end,
};
ActorManager = {
	getRecordType = function(v)
		local s = (type(v) == "string") and v or v.path;
		if s:match("^npc%.") then return "npc"; end
		if s:match("^charsheet%.") then return "charsheet"; end
		return "";
	end,
};
ActorCommonManager = { getSpaceReach = function() return 10, 5; end };

local tCT = {};
CombatRecordManager = {
	hasRecordTypeCallback = function(s) return s == "npc" or s == "charsheet"; end,
	onRecordTypeEvent = function(_, tCustom)
		assert(tCustom.tPlacement == nil, "adding from the menu must not place a token");
		tCustom.nodeCT = DB.createChild(DB.createNode("combattracker.list"));
		DB.setValue(tCustom.nodeCT, "token", "token", tCustom.sToken);
		table.insert(tCT, tCustom);
		return true;
	end,
};
CombatManager = {
	getCTFromNode = function(s) for _,t in ipairs(tCT) do if t.sRecord == s then return t.nodeCT; end end end,
	replaceCombatantToken = function(nodeCT, tokenMap)
		local x, y = tokenMap.getPosition();
		local tokenNew = newToken(tokenMap.getContainerNode(), { asset = DB.getValue(nodeCT, "token", ""), x = x, y = y });
		tokenMap.delete();
		tokenNew.inCT = true;
		CombatManager.linked = tokenNew;
	end,
};

dofile(arg[1]);
NonCombatTokens = _G;

onInit();
onTabletopInit();
assert(tDropCallbacks["token"] == onImageTokenDrop, "drop callback replaced");
assert(ImageManager.onImageTokenDrop == onImageTokenDrop, "ImageManager.onImageTokenDrop replaced");

local nodeImage = newNode("image.id-00001.image");
local nodeNPC = newNode("npc.id-00001");
DB.setValue(nodeNPC, "name", "string", "Goblin");
local nodeHidden = newNode("npc.id-00002");
DB.setValue(nodeHidden, "name", "string", "Goblin King");
DB.setValue(nodeHidden, "nonid_name", "string", "Big Goblin");
DB.setValue(nodeHidden, "isidentified", "number", 0);
newNode("charsheet.id-00001");

local cImage = {
	snapToGrid = function(x, y) return x - (x % 50), y - (y % 50); end,
	getDatabaseNode = function() return nodeImage; end,
};
local function drag(sClass, sRecord, sToken)
	return {
		getShortcutData = function() return sClass, sRecord; end,
		getTokenData = function() return sToken; end,
	};
end
local function lastToken() return tTokens[nNextToken]; end
local function entries() local n = DB.findNode(DATA_NODE); return n and #n.children or 0; end

-- NPC drop: token only, named, with menu and link
assert(tDropCallbacks["token"](cImage, 123, 77, drag("npc", "npc.id-00001", "tokens/goblin.png")) == true);
local token = lastToken();
assert(#tCT == 0, "not added to CT");
assert(token.x == 100 and token.y == 50, "snapped to grid");
assert(token.asset == "tokens/goblin.png");
assert(token.name == "Goblin");
assert(token.menu[MENU_SLOT] == "noncombattokens_menu_addtoct", "menu registered");
assert(entries() == 1);
assert(ImageManagerOrigCalled == nil);
print("npc drop OK");

-- Unidentified NPC uses the non-id name; deleting the token removes the link
tDropCallbacks["token"](cImage, 0, 0, drag("npc", "npc.id-00002", "tokens/king.png"));
assert(lastToken().name == "Big Goblin");
lastToken().delete();
assert(entries() == 1, "deleting the token removes the link");
print("non-id name and delete OK");

-- PCs and loose tokens keep the default behavior
tDropCallbacks["token"](cImage, 0, 0, drag("charsheet", "charsheet.id-00001", "tokens/pc.png"));
assert(ImageManagerOrigCalled == true, "PC uses default behavior");
ImageManagerOrigCalled = nil;
tDropCallbacks["token"](cImage, 0, 0, drag("", "", "tokens/loose.png"));
assert(ImageManagerOrigCalled == true, "loose token uses default behavior");
ImageManagerOrigCalled = nil;
print("default drops OK");

-- Double click opens the record; unlinked tokens do nothing
assert(TokenManager.handleDoubleClickOpen(token) == true);
assert(Interface.opened[1] == "npc" and Interface.opened[2] == "npc.id-00001");
Interface.opened = nil;
local tokenLoose = newToken(nodeImage, { asset = "x.png", x = 0, y = 0 });
assert(TokenManager.handleDoubleClickOpen(tokenLoose) == false and Interface.opened == nil);
print("double click OK");

-- Reloading the image re-registers the menu
token.menu = {};
fire("onAdd", token, true);
assert(token.menu[MENU_SLOT], "menu on load");
print("menu on load OK");

-- Moving to another image updates the link
local nodeImage2 = newNode("image.id-00002.image");
local nOldId = token.id;
token.container = nodeImage2; token.id = 99;
fire("onContainerChanged", token, nodeImage, nOldId);
assert(getEntry(token) ~= nil and entries() == 1, "link moved to new image");
print("container change OK");

-- Only the top-level menu slot adds to the CT
fire("onMenuSelection", token, MENU_SLOT, 1);
fire("onMenuSelection", token, MENU_SLOT + 1);
assert(#tCT == 0);
fire("onMenuSelection", token, MENU_SLOT);
assert(#tCT == 1 and tCT[1].sRecord == "npc.id-00001" and tCT[1].sToken == "tokens/goblin.png");
assert(entries() == 0, "link removed once in CT");
assert(tTokens[99] == nil and CombatManager.linked.inCT, "token replaced by CT token");
assert(CombatManager.linked.x == 100 and CombatManager.linked.y == 50, "same position");
print("add to CT OK");

-- NPC already in the CT keeps the default behavior
tDropCallbacks["token"](cImage, 0, 0, drag("npc", "npc.id-00001", "tokens/goblin.png"));
assert(ImageManagerOrigCalled == true);
ImageManagerOrigCalled = nil;
print("npc already in CT OK");

-- Deleted record: error message, no changes
tDropCallbacks["token"](cImage, 0, 0, drag("npc", "npc.id-00002", "tokens/king.png"));
local tokenOrphan = lastToken();
DB.deleteNode(nodeHidden);
assert(TokenManager.handleDoubleClickOpen(tokenOrphan) == false);
assert(addTokenToCT(tokenOrphan) == false and tStrings[#tStrings] == "noncombattokens_error_norecord");
print("deleted record OK");

print("all tests OK");
