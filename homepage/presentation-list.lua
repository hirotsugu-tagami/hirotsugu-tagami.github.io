local function stringify(value)
  if value == nil then
    return ""
  end
  return pandoc.utils.stringify(value)
end

local function parse_inlines(markdown)
  local document = pandoc.read(markdown, "markdown")
  local block = document.blocks[1]
  return block and block.content or pandoc.List()
end

local function metadata_inlines(value)
  if value == nil then
    return pandoc.List()
  end

  if type(value) == "string" then
    return parse_inlines(value)
  end

  if value.t == "MetaInlines" and value.c then
    return pandoc.List(value.c)
  end

  if type(value) == "table" and #value > 0 then
    return pandoc.List(value)
  end

  return parse_inlines(stringify(value))
end

local function read_presentations()
  local project_directory = quarto.project.directory or "."
  local data_path = project_directory .. "/presentations.yml"
  local file = io.open(data_path, "r")
  if not file then
    error(data_path .. " could not be opened")
  end

  local contents = file:read("*a")
  file:close()

  local metadata_document = pandoc.read("---\n" .. contents .. "\n---\n", "markdown")
  return metadata_document.meta.presentations or pandoc.List()
end

local function is_true(value)
  return value == true or stringify(value) == "true"
end

local function author_inlines(authors)
  local inlines = pandoc.List()

  for index, author in ipairs(authors or {}) do
    if index > 1 then
      inlines:insert(pandoc.Str(","))
      inlines:insert(pandoc.Space())
    end

    local name = parse_inlines(stringify(author.name))
    if is_true(author.me) then
      inlines:insert(pandoc.Span(name, pandoc.Attr("", { "highlight-author" })))
    else
      inlines:extend(name)
    end
  end

  return inlines
end

local function presentation_item(presentation)
  local presentation_type = stringify(presentation.type)
  local type_class = "status-" .. presentation_type:lower()
  local inlines = pandoc.List({
    pandoc.Span(
      { pandoc.Str(presentation_type) },
      pandoc.Attr("", { "presentation-status", type_class })
    ),
    pandoc.Space()
  })

  inlines:extend(author_inlines(presentation.authors))
  inlines:insert(pandoc.LineBreak())
  inlines:insert(pandoc.Strong({ pandoc.Emph(metadata_inlines(presentation.title)) }))
  inlines:insert(pandoc.LineBreak())

  local details = table.concat({
    stringify(presentation.conference),
    stringify(presentation.location),
    stringify(presentation.date)
  }, ", ")

  inlines:extend(parse_inlines(details))
  if stringify(presentation.status) == "upcoming" then
    inlines:insert(pandoc.Str("（発表予定）"))
  end

  return { pandoc.Plain(inlines) }
end

local function group_by_year(presentations)
  local groups = {}
  local years = {}

  for _, presentation in ipairs(presentations) do
    local year = stringify(presentation.year)
    if groups[year] == nil then
      groups[year] = {}
      table.insert(years, year)
    end
    table.insert(groups[year], presentation)
  end

  table.sort(years, function(left, right)
    return tonumber(left) > tonumber(right)
  end)

  return years, groups
end

local function year_group(year, presentations)
  local items = {}
  for _, presentation in ipairs(presentations) do
    table.insert(items, presentation_item(presentation))
  end

  local list = pandoc.OrderedList(items)
  local list_div = pandoc.Div({ list }, pandoc.Attr("", { "presentation-list" }))

  return pandoc.Div(
    { list_div },
    pandoc.Attr(
      "",
      { "presentation-year-data" },
      {
        ["data-year"] = year .. "年度",
        ["data-open"] = "false"
      }
    )
  )
end

function Div(div)
  if div.identifier ~= "presentations-list" then
    return nil
  end

  local presentations = read_presentations()
  local years, groups = group_by_year(presentations)
  local blocks = pandoc.List()

  for _, year in ipairs(years) do
    blocks[#blocks + 1] = year_group(year, groups[year])
  end

  return blocks
end
