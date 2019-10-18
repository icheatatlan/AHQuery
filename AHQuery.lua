local items = {}
local to_announce = {}
local available_price_sources = {}
local config = {
  price_sources = {},
}

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
  return fmt:sub(1, fmt:len() - 1)
end

local queue_announcement = function (itemID, source, sender)
  to_announce[itemID] = { source = source, sender = sender }
end

local announce = function ()
  local queue = to_announce
  to_announce = {}

  for itemID, source in pairs(queue) do
    local _, itemLink = GetItemInfo(itemID)

    local price_strs = {}
    for _, source in ipairs(config.price_sources) do
      local f = source.fn(itemID)
      if f then
        table.insert(price_strs, source.name .. ': ' .. f)
      end
    end

    if #price_strs > 0 then
      local formatted = table.concat(price_strs, ' || ')
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

local build_price_sources = function ()
  local tsm = TSMAPI_FOUR and TSMAPI_FOUR.CustomPrice and TSMAPI_FOUR.CustomPrice.GetItemPrice
  local bbg = TUJMarketInfo
  local auc_market = AucAdvanced and AucAdvanced.API.GetMarketValue
  local auc_buyout = AucAdvanced and AucAdvanced.Modules.Util.SimpleAuction and AucAdvanced.Modules.Util.SimpleAuction.Private.GetItems

  if tsm then
    available_price_sources['TSM'] = function (itemID)
      local market_value = tsm(itemID, 'DBMarket')
      local region_market_value = tsm(itemID, 'DBRegionMarketAvg')
      local min_buyout = tsm(itemID, 'DBMinBuyout')
      local region_min_buyout = tsm(itemID, 'DBRegionMinBuyoutAvg')

      if market_value or region_market_value or min_buyout or region_min_buyout then
        return string.format(
          'realm %s (min. %s), region %s (min. %s)',
          format_price(market_value),
          format_price(min_buyout),
          format_price(region_market_value),
          format_price(region_min_buyout)
        )
      end

      return nil
    end
  end

  if bbg then
    available_price_sources['BBG'] = function (itemID)
      local p = TUJMarketInfo(itemID)
      if p then
        return string.format(
          'realm %s ± %s, global %s ± %s',
          format_price(p['market']),
          format_price(p['stddev']),
          format_price(p['globalMean']),
          format_price(p['globalStdDev'])
        )
      end

      return nil
    end
  end

  if auc_market or auc_buyout then
    available_price_sources['AUC'] = function (itemID)
      local market_value = auc_market and auc_market(itemID) or nil
      local min_buyout = auc_buyout and select(6, auc_buyout(itemID)) or nil

      if not market_value and not min_buyout then
        return nil
      end

      return string.format(
        'realm %s (min. %s)',
        format_price(market_value),
        format_price(min_buyout)
      )
    end
  end
end

local autoconfigure_price_sources = function ()
  local private_source = nil
  local public_source = nil

  -- first, choose a 'private' source for more readily updated pricing
  if available_price_sources['TSM'] then
    private_source = 'TSM'
  elseif available_price_sources['AUC'] then
    private_source = 'AUC'
  end

  -- second, choose a 'public' source for aggregate pricing (e.g. BBG)
  -- for now, only BBG/TUJ is supported
  if available_price_sources['BBG'] then
    public_source = 'BBG'
  end

  if private_source then
    table.insert(config.price_sources, { name = private_source, fn = available_price_sources[private_source] })
  end

  if public_source then
    table.insert(config.price_sources, { name = public_source, fn = available_price_sources[public_source] })
  end
end

local save_config = function ()
  local price_sources = {}
  for _, price_source in ipairs(config.price_sources) do
    table.insert(price_sources, price_source.name)
  end

  AHQuery_Config.price_sources = price_sources
end

local load_config = function ()
  if not AHQuery_Config then
    AHQuery_Config = {
      price_sources = {},
    }
    autoconfigure_price_sources()
  else
    for _, name in ipairs(AHQuery_Config.price_sources) do
      local price_source = available_price_sources[name]
      if price_source then
        table.insert(config.price_sources, { name = name, fn = available_price_sources[name] })
      end
    end
  end

  save_config()
end

SLASH_AHQUERY1 = '/ahquery'
SlashCmdList['AHQUERY'] = function (arg_str)
  local cmd = nil
  local rest = nil

  local space = arg_str:find(' ')
  if space then
    cmd = arg_str:sub(1, space - 1)
    rest = arg_str:sub(space + 1)
  else
    cmd = arg_str
  end

  if cmd == 'sources' then
    local source_names = {}
    for source_name, _ in pairs(available_price_sources) do
      table.insert(source_names, source_name)
    end

    if #source_names == 0 then
      print('No price sources are available.  Install a supported auction database addon to use AHQuery.')
      return
    end

    local message = 'Available price sources: ' .. table.concat(source_names, ' ')

    source_names = {}
    for _, source in ipairs(config.price_sources) do
      table.insert(source_names, source.name)
    end

    if #source_names > 0 then
      message = message .. ' || Enabled: ' .. table.concat(source_names, ' ')
    else
      message = message .. ' || No sources are enabled'
    end

    print(message)
  elseif cmd == 'toggle' and rest then
    local source_name = string.upper(rest)

    local enabled_index = nil
    for i, source in ipairs(config.price_sources) do
      if source.name == source_name then
        enabled_index = i
      end
    end

    if enabled_index then
      table.remove(config.price_sources, enabled_index)
      print('Disabled price source ' .. source_name)

      if #config.price_sources == 0 then
        print('No price sources are enabled.  Price checks will not be responded to.')
      end
    elseif available_price_sources[source_name] then
      table.insert(config.price_sources, { name = source_name, fn = available_price_sources[source_name] })
      print('Enabled price source ' .. source_name)
    else
      print('The price source ' .. source_name .. ' is not available.  Check to see if the addon is installed and up to date.')
    end
  elseif cmd == 'reset' then
    config.price_sources = {}
    autoconfigure_price_sources()
    save_config()

    local source_names = {}
    for _, source in ipairs(config.price_sources) do
      table.insert(source_names, source.name)
    end

    print('Selected price sources: ' .. table.concat(source_names, ' '))
  else
    print('Usage: /ahquery sources || /ahquery toggle <source> || /ahquery reset')
  end
end


build_price_sources()

local frame = CreateFrame('frame', 'AHQueryEventFrame')
frame:RegisterEvent('ADDON_LOADED')
frame:RegisterEvent('PLAYER_LOGOUT')
frame:RegisterEvent('CHAT_MSG_GUILD')
frame:RegisterEvent('CHAT_MSG_OFFICER')
frame:RegisterEvent('CHAT_MSG_PARTY')
frame:RegisterEvent('CHAT_MSG_PARTY_LEADER')
frame:RegisterEvent('CHAT_MSG_RAID')
frame:RegisterEvent('CHAT_MSG_RAID_LEADER')
frame:RegisterEvent('CHAT_MSG_WHISPER')
frame:SetScript('OnEvent', function (self, event, ...)
  if event == 'ADDON_LOADED' then
    local addon = ...
    if addon == 'AHQuery' then
      load_config()
    end

    return
  elseif event == 'PLAYER_LOGOUT' then
    save_config()
  end

  -- anything else is a chat message
  local msg, sender = ...
  local source = event:sub(string.len('CHAT_MSG_') + 1):gsub('_LEADER', '')
  handle_message(msg, source, sender)
end)

C_Timer.NewTicker(1, announce)

