local items = {}
local to_announce = {}

local format_price = function (price)
  if not price then
    return '?'
  end

  price = floor(tonumber(price, 10))

  local c = price % 100
  price = floor(price / 100)

  local s = price % 100
  price = floor(price / 100)

  local g = price

  local fmt = (g > 0 and tostring(g) .. 'g ' or '') .. (s > 0 and tostring(s) .. 's ' or '') .. (c > 0 and tostring(c) .. 'c ' or '')
  return fmt:match('^%s*(.-)%s*$')
end

local queue_announcement = function (itemID, source, sender)
  to_announce[itemID] = { source = source, sender = sender }
end

local announce = function ()
  local hasTSM = TSMAPI_FOUR and TSMAPI_FOUR.CustomPrice and TSMAPI_FOUR.CustomPrice.GetItemPrice
  local hasBBG = TUJMarketInfo

  local queue = to_announce
  to_announce = {}

  for itemID, source in pairs(queue) do
    local _, itemLink = GetItemInfo(itemID)

    local tsmInfo = nil
    if hasTSM then
      local marketValue = TSMAPI_FOUR.CustomPrice.GetItemPrice(itemID, 'DBMarket')
      local regionMarketValue = TSMAPI_FOUR.CustomPrice.GetItemPrice(itemID, 'DBRegionMarketAvg')
      local minBuyout = TSMAPI_FOUR.CustomPrice.GetItemPrice(itemID, 'DBMinBuyout')
      local regionMinBuyout = TSMAPI_FOUR.CustomPrice.GetItemPrice(itemID, 'DBRegionMinBuyoutAvg')

      if marketValue or regionMarketValue or minBuyout or regionMinBuyout then
        tsmInfo = string.format('TSM: realm %s (min. %s), region %s (min. %s)', format_price(marketValue), format_price(minBuyout), format_price(regionMarketValue), format_price(regionMinBuyout))
      end
    end

    local bbgInfo = nil
    if hasBBG then
      local p = TUJMarketInfo(itemID)
      if p then
        bbgInfo = string.format('BBG: realm %s ± %s, global %s ± %s', format_price(p['market']), format_price(p['stddev']), format_price(p['globalMean']), format_price(p['globalStdDev']))
      end
    end

    local formatted = nil
    if tsmInfo and bbgInfo then
      formatted = tsmInfo .. ' {rt1} ' .. bbgInfo
    elseif bbgInfo or tsmInfo then
      formatted = (tsmInfo or '') .. (bbgInfo or '')
    end

    if formatted then
      SendChatMessage(itemLink .. ' ' .. formatted, source.source, nil, source.source == 'WHISPER' and source.sender or nil)
    end
  end
end

local handle_message = function (msg, source, sender)
  if not msg:find('!price') then
    return
  end

  for itemString in msg:gsub('item[%-?%d:]+','\0%0\0'):gsub('%z%z',''):gmatch('%z(.-)%z') do
    local _, _, itemID = string.find(itemString, 'item:(%d+)')
    itemID = tonumber(itemID, 10)

    if not items[itemID] then
      items[itemID] = 0
      local item = Item:CreateFromItemID(itemID)
      item:ContinueOnItemLoad(function ()
        items[itemID] = 1
        queue_announcement(itemID, source, sender)
      end)
    else
      queue_announcement(itemID, source, sender)
    end
  end
end

local frame = CreateFrame('frame', 'AHQueryEventFrame')
frame:RegisterEvent('CHAT_MSG_GUILD')
frame:RegisterEvent('CHAT_MSG_OFFICER')
frame:RegisterEvent('CHAT_MSG_PARTY')
frame:RegisterEvent('CHAT_MSG_PARTY_LEADER')
frame:RegisterEvent('CHAT_MSG_RAID')
frame:RegisterEvent('CHAT_MSG_RAID_LEADER')
frame:RegisterEvent('CHAT_MSG_WHISPER')
frame:SetScript('OnEvent', function (self, event, ...)
  local msg, sender = ...
  local source = event:sub(string.len('CHAT_MSG_') + 1):gsub('_LEADER', '')
  handle_message(msg, source, sender)
end)

C_Timer.NewTicker(1, announce)

