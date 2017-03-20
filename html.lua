-- * Usage
--
-- Parsing file:
--
--  local html = require "html"
--  html.parse(io.stdin)
--
-- Parsing string:
--
--  local html = require "html"
--  html.parsestr("<html></html>")
--
--
-- * Author
--
-- T. Kobayashi
-- ether @nospam@ users.sourceforge.jp
--
--

local entity = {
  nbsp = " ",
  lt = "<",
  gt = ">",
  quot = "\"",
  amp = "&",
}

-- keep unknown entity as is
setmetatable(entity, {
  __index = function (t, key)
    return "&" .. key .. ";"
  end
})

local block = {
  "address",
  "blockquote",
  "center",
  "dir", "div", "dl",
  "fieldset", "form",
  "h1", "h2", "h3", "h4", "h5", "h6", "hr",
  "isindex",
  "menu",
  "noframes",
  "ol",
  "p",
  "pre",
  "table",
  "ul",
}

local inline = {
  "a", "abbr", "acronym", "applet",
  "b", "basefont", "bdo", "big", "br", "button",
  "cite", "code",
  "dfn",
  "em",
  "font",
  "i", "iframe", "img", "input",
  "kbd",
  "label",
  "map",
  "object",
  "q",
  "s", "samp", "select", "small", "span", "strike", "strong", "sub", "sup",
  "textarea", "tt",
  "u",
  "var",
}

local tags = {
  area = {empty = true} ,
  base = {empty = true} ,
  basefont = {empty = true} ,
  br = {empty = true} ,
  col = {empty = true} ,
  colgroup = {
    empty = false,
    optional_end = true,
    child = {"col",},
  },
  dt = {
    empty = false,
    optional_end = true,
    child = {
      inline,
      "del",
      "ins",
      "noscript",
      "script",
    },
  },
  frame = {empty = true} ,
  hr = {empty = true} ,
  img = {empty = true} ,
  input = {empty = true} ,
  isindex = {empty = true} ,
  li = {
    empty = false,
    optional_end = true,
    child = {
      inline,
      block,
      "del",
      "ins",
      "noscript",
      "script",
    },
  },
  link = {empty = true} ,
  meta = {empty = true} ,
  option = {
    empty = false,
    optional_end = true,
    child = {},
  },
  p = {
    empty = false,
    optional_end = true,
    child = {
      inline,
      "del",
      "ins",
      "noscript",
      "script",
    },
  } ,
  param = {empty = true} ,
  td = {
    empty = false,
    optional_end = true,
    child = {
      inline,
      block,
      "del",
      "ins",
      "noscript",
      "script",
    },
  },
  tfoot = {
    empty = false,
    optional_end = true,
    child = {"tr",},
  },
  th = {
    empty = false,
    optional_end = true,
    child = {
      inline,
      block,
      "del",
      "ins",
      "noscript",
      "script",
    },
  },
  thead = {
    empty = false,
    optional_end = true,
    child = {"tr",},
  },
  tr = {
    empty = false,
    optional_end = true,
    child = {
      "td", "th",
    },
  },
}

setmetatable(tags, {
  __index = function (t, key)
    return {empty = false}
  end
})

-- string buffer implementation
local function newbuf ()
  local buf = {
    _buf = {},
    clear =   function (self) self._buf = {}; return self end,
    content = function (self) return table.concat(self._buf) end,
    append =  function (self, s)
      self._buf[#(self._buf) + 1] = s
      return self
    end,
    set =     function (self, s) self._buf = {s}; return self end,
  }
  return buf
end

-- unescape character entities
local function unescape (s)
  return s:gsub("&(#?%w+);", entity)
end

-- iterator factory
local function makeiter (f)
  local co = coroutine.create(f)
  return function ()
    local code, res = coroutine.resume(co)
    return res
  end
end

-- constructors for token
local function Tag (s)
  return s:find("^</") and
    {type = "End",   value = s} or
    {type = "Start", value = s}
end

-- <!DOCTYPE ...>
-- <!-- .... -->
-- <?xml .... > buggy html
local function SpecialTreat (s)
  return {type = "SpecialTreat", value = s}
end

local function Text (s)
  local unescaped = unescape(s)
  return {type = "Text", value = unescaped}
end

local tag, specialTreat

-- lexer: text mode
local function text (f, buf)
  local c = f:read(1)
  if c == "<" then
    if buf:content() ~= "" then coroutine.yield(Text(buf:content())) end
    buf:set(c)
    ------Edited---------
    c = f:read(1)
    if c == '!' or c == '?' then
      buf:append(c)
      return specialTreat(f, buf)
    elseif c then
      buf:append(c)
      return tag(f, buf)
    else
      if buf:content() ~= "" then coroutine.yield(Text(buf:content())) end
    end
    ------Edited---------
  elseif c then
    buf:append(c)
    return text(f, buf)
  else
    if buf:content() ~= "" then coroutine.yield(Text(buf:content())) end
  end
end

------Edited---------
function specialTreat(f, buf)
  local c = f:read(1)
  if c == ">" then
    buf:append(c)
    if buf:content():match("^<!%-%-.*%-%->$") or
       buf:content():match("^<%?.+>$") or
       buf:content():match("^<!DOCTYPE%s+HTML[^>]+>$")
    then
      coroutine.yield(SpecialTreat(buf:content()))
      buf:clear()
      return text(f, buf)
    else
      return specialTreat(f, buf)
    end
  elseif c then
    buf:append(c)
    return specialTreat(f, buf)
  else
    if buf:content() ~= "" then coroutine.yield(SpecialTreat(buf:content())) end
  end
end

local function fullQuotedStr(f, q)
  local qStr = q
  local c
  repeat
    c = f:read(1)
    if c then
      qStr = qStr .. c
    end
  until (not c or (c == q))
  if not c then qStr = qStr .. q end
  return qStr, c
end
------Edited---------

-- lexer: tag mode
function tag (f, buf)
  local c = f:read(1)
  ------Edited---------
  if c == "'" or c == '"' then
    local qStr, QSymbol = fullQuotedStr(f, c)
    buf:append(qStr)
    if QSymbol ~= c then
      if buf:content() ~= "" then coroutine.yield(Tag(buf:content())) end
    else
      return tag(f, buf)
    end
  elseif c == "<" then
    coroutine.yield(Text(buf:content()))
    buf:clear()
    buf:append(c)
    return tag(f, buf)
  elseif c == ">" then
    buf:append(c)
    local tagBuf = buf:content()
    if not tagBuf:find("^</?%s*%w*") then
      -- some buggy html file
      coroutine.yield(Text(buf:content()))
    else
      coroutine.yield(Tag(buf:content()))
    end
  ------Edited---------
    buf:clear()
    return text(f, buf)
  elseif c then
    buf:append(c)
    return tag(f, buf)
  else
    if buf:content() ~= "" then coroutine.yield(Tag(buf:content())) end
  end
end

-- 
local function parse_starttag(tag)
  local tagname = tag:match("<%s*([^>%s]+)")
  local elem = {_attr = {}}
  elem._tag = tagname
  -- buggy: <a alt=something ...> attributes with no quotation marks
  for key, _, val in tag:gmatch("(%w+)%s*=%s*([\"'])(.-)%2", i) do
    local unescaped = unescape(val)
    elem._attr[key] = unescaped
  end
  for key, val in tag:gmatch("(%w+)%s*=%s*([^\"'%s]+)[%s>]", i) do
    local unescaped = unescape(val)
    elem._attr[key] = unescaped
  end

  return elem
end

local function parse_endtag(tag)
  local tagname = tag:match("<%s*/%s*([^>%s]+)")
  return tagname
end

-- find last element that satisfies given predicate
local function rfind(t, pred)
  local length = #t
  for i=length,1,-1 do
    if pred(t[i]) then
      return i, t[i]
    end
  end
end

local function flatten(t, acc)
  acc = acc or {}
  for i,v in ipairs(t) do
    if type(v) == "table" then
      flatten(v, acc)
    else
      acc[#acc + 1] = v
    end
  end
  return acc
end

local function optional_end_p(elem)
  if tags[elem._tag].optional_end then
    return true
  else
    return false
  end
end

local function valid_child_p(child, parent)
  local schema = tags[parent._tag].child
  if not schema then return true end

  for i,v in ipairs(flatten(schema)) do
    if v == child._tag then
      return true
    end
  end

  return false
end

-- tree builder
local function parse(f)
  local root = {_tag = "#document", _st = true, _stText = "", _attr = {}} -- _st = special treat
  local stack = {root}
  for i in makeiter(function () return text(f, newbuf()) end) do
    if i.type == "Start" then
      local new = parse_starttag(i.value)
      local top = stack[#stack]

      while
        top._tag ~= "#document" and
        optional_end_p(top) and
        not valid_child_p(new, top)
      do
        stack[#stack] = nil
        top = stack[#stack]
      end

      top[#top+1] = new -- appendchild
      if not tags[new._tag].empty then
        stack[#stack+1] = new -- push
      end
    elseif i.type == "End" then
      local tag = parse_endtag(i.value)
      local openingpos = rfind(stack, function(v)
        if v._tag == tag then
          return true
        else
          return false
        end
      end)
      if openingpos then
        local length = #stack
        for j=length,openingpos,-1 do
          table.remove(stack, j)
        end
      end
    elseif i.type == "SpecialTreat" then -- For: <!--.*--> or <!DOCTYPE ...>
      local top = stack[#stack]
      top[#top+1] = {_st = true, _stText = i.value}
    else -- Text
      local top = stack[#stack]
      top[#top+1] = i.value
    end
  end
  return root
end

local function parsestr(s)
  local handle = {
    _content = s,
    _pos = 1,
    read = function (self, length)
      if self._pos > #self._content then return end
      local ret = self._content:sub(self._pos, self._pos + length - 1)
      self._pos = self._pos + length
      return ret
    end
  }
  return parse(handle)
end

return {
  parse = parse,
  parsestr = parsestr,
}

