-- Inofficial KuCoin Extension (https://kucoin.com) for MoneyMoney
-- Fetches balances from KuCoin API and returns them as securities
--
-- Username: KuCoin API Key
-- Password: KuCoin API Secret
--
-- Copyright (c) 2018 Lukas Besch
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking {
  version     = 0.1,
  url         = "https://api.kucoin.com",
  description = "Fetch balances from KuCoin API and list them as securities",
  services    = { "KuCoin Account" }
}

local apiKey
local apiSecret
local apiPassphrase
local balances = {}
local currency
local connection = Connection()

local currencySymbols = {
}

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "KuCoin Account"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  apiKey = ''
  apiSecret = ''
  apiPassphrase = ''
  currency = "EUR"
end

function ListAccounts (knownAccounts)
  local account = {
    name = market,
    accountNumber = "KuCoin Account",
    currency = currency,
    portfolio = true,
    type = "AccountTypePortfolio"
  }

  return {account}
end

function appendBalances(newBalances)
  for k,v in pairs(newBalances) do
    if tonumber(v.balance) > 0 then
      table.insert(balances, v)
    end
  end
end

function appendTable(table, content)
  for k,v in pairs(content) do
    table[k] = v
  end
end

function RefreshAccount (account, since)

  local response = queryPrivate()
  local pages = response.data.total / 20
  appendBalances(response.data.datas)
  local i = 1
  while i <= pages do
    i = i + 1
    response = queryPrivate(i)
    appendBalances(response.data.datas)
  end

  local eurPrices = assetPrices()
  local fallbackTable = {}
  fallbackTable["EUR"] = 0

  local s = {}
  for key, value in pairs(balances) do
    if tonumber(value.balance) > 0 then
      s[#s+1] = {
        name = value.coinType,
        market = market,
        currency = nil,
        quantity = value.balance,
        price = (eurPrices[symbolForAsset(value.coinType)] or fallbackTable)["EUR"],
      }
    end
  end

  return {securities = s}
end

function symbolForAsset(asset)
  return currencySymbols[asset] or asset
end

function assetPrices()
  local assets = ""
  local eurPrices = {}
  for key, value in pairs(balances) do
    if tonumber(value.balance) > 0 then
      assets = assets .. symbolForAsset(value.coinType) .. ','
    end
    if string.len(assets) >= 280 then
      newPrices = queryCryptoCompare("pricemulti", "?fsyms=" .. assets .. "&tsyms=EUR")
      appendTable(eurPrices, newPrices)
      assets = ""
    end
  end
  return eurPrices
end

function EndSession ()
end

function bin2hex(s)
 return (s:gsub(".", function (byte)
   return string.format("%02x", string.byte(byte))
 end))
end

function httpBuildQuery(params)
  local str = ''
  for key, value in pairs(params) do
    str = str .. key .. "=" .. value .. "&"
  end
  return str.sub(str, 1, -2)
end

function queryPrivate()
  local host = 'https://api.kucoin.com';
  local endpoint ='/api/v1/accounts';
  local url = host .. endpoint;
  local method = 'GET'
  local query = {}
  -- queryString = httpBuildQuery(query)
  local queryString = ''

  local posixTimestamp = MM.time()
  local timestamp = string.format("%d", posixTimestamp * 1000)
  local strForSign = timestamp .. method .. endpoint .. queryString;
  local digest = MM.hmac256(strForSign, apiSecret); -- returns binary data
  local signatureStr = MM.base64(digest);
  -- see https://moneymoney-app.com/api/webbanking/

  local headers = {}
  headers["KC-API-KEY"] = apiKey
  headers["KC-API-SIGNATURE"] = signatureStr
  headers["KC-API-PASSPHRASE"] = apiPassphrase
  headers["KC-API-TIMESTAMP"] = timestamp

  local content, charset, mimeType, filename, headers = connection:request(method, url, queryString, "Content-Type: application/json", headers)
  json = JSON(content)

  return json:dictionary()
end

function queryCryptoCompare(method, query)
  local path = string.format("/%s/%s", "data", method)

  connection = Connection()
  content = connection:request("GET", "https://min-api.cryptocompare.com" .. path .. query)
  json = JSON(content)

  return json:dictionary()
end
