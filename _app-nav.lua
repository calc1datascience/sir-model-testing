-- Adds "Previous / All apps / Next" links to the top and bottom of every
-- page in the apps/ folder. The order comes from the file names
-- (01-..., 02-..., ...), and the link text comes from each app's title,
-- so new apps are picked up automatically. Nothing to edit by hand.

local function read_title(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local in_header = false
  for line in f:lines() do
    if line:match("^%-%-%-%s*$") then
      if in_header then break end
      in_header = true
    elseif in_header then
      local t = line:match("^title:%s*(.-)%s*$")
      if t then
        f:close()
        return (t:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1"))
      end
    end
  end
  f:close()
  return nil
end

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function nav_html(prev, nxt, where)
  local left, right = "<span></span>", "<span></span>"
  if prev then
    left = string.format(
      '<a class="app-nav-link app-nav-prev" href="%s"><span class="app-nav-label">← Previous</span><span class="app-nav-title">%s</span></a>',
      prev.href, esc(prev.title))
  end
  if nxt then
    right = string.format(
      '<a class="app-nav-link app-nav-next" href="%s"><span class="app-nav-label">Next →</span><span class="app-nav-title">%s</span></a>',
      nxt.href, esc(nxt.title))
  end
  local home = '<a class="app-nav-home" href="../index.html">All apps</a>'
  return string.format('<nav class="app-nav app-nav-%s" aria-label="App navigation">%s%s%s</nav>',
    where, left, home, right)
end

function Pandoc(doc)
  local input = quarto.doc.input_file
  if not input then return doc end
  local dir = pandoc.path.directory(input)
  if pandoc.path.filename(dir) ~= "apps" then return doc end

  local files = {}
  for _, name in ipairs(pandoc.system.list_directory(dir)) do
    if name:match("%.qmd$") and not name:match("^_") then
      table.insert(files, name)
    end
  end
  table.sort(files)

  local me = pandoc.path.filename(input)
  local idx
  for i, name in ipairs(files) do
    if name == me then idx = i end
  end
  if not idx then return doc end

  local function entry(i)
    local name = files[i]
    if not name then return nil end
    return {
      href = name:gsub("%.qmd$", ".html"),
      title = read_title(pandoc.path.join({ dir, name })) or name,
    }
  end
  local prev, nxt = entry(idx - 1), entry(idx + 1)

  table.insert(doc.blocks, 1, pandoc.RawBlock("html", nav_html(prev, nxt, "top")))
  table.insert(doc.blocks, pandoc.RawBlock("html", nav_html(prev, nxt, "bottom")))
  return doc
end
