-- "Fill object initializer" code actions for C#.
--
-- Roslyn has no refactoring that fills in `new Foo { }` with the members of
-- `Foo`; in Visual Studio that comes from extensions or per-project NuGet
-- analyzers. This does it editor-side instead, so it works in every project
-- without touching a .csproj: a tiny in-process LSP "server" that attaches
-- next to Roslyn and contributes to the normal code action menu
-- (`<leader>ca`) whenever the cursor is inside an object initializer:
--
--   * "Fill object initializer"             -> `Name = default,` per member,
--                                              as snippet placeholders
--   * "Fill object initializer from 'x'"    -> `Name = x.Name,` for members
--                                              that `x` (a parameter or local
--                                              in scope) also has; the rest
--                                              stay `default` placeholders
--
-- Which members to add comes from Roslyn itself: completion right after the
-- `{` lists exactly the settable members that aren't assigned yet. Everything
-- else (finding the initializer, variables in scope, declaration order) is
-- treesitter. Enabled from lua/plugins/dotnet.lua.
local M = {}

local COMMAND = "cs_object_initializer.fill"
local PROPERTY, FIELD = vim.lsp.protocol.CompletionItemKind.Property, vim.lsp.protocol.CompletionItemKind.Field

local CREATIONS = { object_creation_expression = true, implicit_object_creation_expression = true }
local TYPES = {
  class_declaration = true,
  struct_declaration = true,
  record_declaration = true,
  interface_declaration = true,
}
-- Scopes that end the search for variables; lambdas and local functions
-- aren't listed since they can use what the enclosing method declares.
local FUNCTIONS = {
  method_declaration = true,
  constructor_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
  accessor_declaration = true,
}

---@param node TSNode
---@param type string
---@return TSNode?
local function child_of_type(node, type)
  for child in node:iter_children() do
    if child:type() == type then
      return child
    end
  end
end

--- The `new Foo { ... }` / `new() { ... }` the position is in, and its braces part.
---@return TSNode? creation, TSNode? initializer
local function find_initializer(bufnr, row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return
  end
  parser:parse({ row, row + 1 })
  local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col }, ignore_injections = false })
  while node do
    local type = node:type()
    if CREATIONS[type] then
      return node, child_of_type(node, "initializer_expression")
    elseif type == "block" or type == "declaration_list" then
      return
    end
    node = node:parent()
  end
end

--- Parameters and locals visible from `creation` that could be copied from,
--- nearest first. Variables of built-in types (`int`, `string`...) are left out.
---@param creation TSNode
---@return { name: string, row: integer, col: integer }[]
local function variables_in_scope(bufnr, creation)
  local found, seen = {}, {}
  ---@param name TSNode?
  ---@param type TSNode?
  local function add(name, type)
    if not name or (type and type:type() == "predefined_type") then
      return
    end
    local text = vim.treesitter.get_node_text(name, bufnr)
    if not seen[text] then
      seen[text] = true
      local row, col = name:start()
      found[#found + 1] = { name = text, row = row, col = col }
    end
  end
  ---@param list TSNode?
  local function add_parameters(list)
    if not list then
      return
    elseif list:type() == "implicit_parameter" then -- `x => ...`
      return add(list)
    end
    for param in list:iter_children() do
      if param:type() == "parameter" then
        add(param:field("name")[1], param:field("type")[1])
      end
    end
  end

  local _, _, start_byte = creation:start()
  local node = creation:parent()
  while node do
    local type = node:type()
    if type == "block" then
      for statement in node:iter_children() do
        local _, _, end_byte = statement:end_()
        if end_byte > start_byte then
          break
        end
        local declaration = statement:type() == "local_declaration_statement"
          and child_of_type(statement, "variable_declaration")
        for declarator in declaration and declaration:iter_children() or function() end do
          if declarator:type() == "variable_declarator" then
            add(declarator:field("name")[1], declaration:field("type")[1])
          end
        end
      end
    elseif type == "foreach_statement" then
      local left = node:field("left")[1]
      add(left and left:type() == "identifier" and left or nil, node:field("type")[1])
    elseif type == "lambda_expression" or type == "local_function_statement" then
      add_parameters(node:field("parameters")[1])
    elseif FUNCTIONS[type] then
      add_parameters(node:field("parameters")[1])
      break
    elseif TYPES[type] then
      break
    end
    node = node:parent()
  end
  return found
end

--- Names of the instance properties and fields declared by the type at `location`,
--- in declaration order. Reads the source rather than asking the server, so it
--- only sees what that one declaration spells out (no inherited members).
---@param location lsp.Location|lsp.LocationLink
---@param encoding string
---@return string[]?
local function declared_members(location, encoding)
  local uri = location.uri or location.targetUri
  local range = location.range or location.targetSelectionRange
  if not uri or not range then
    return
  end
  local fname = vim.uri_to_fname(uri)
  if not fname:match("%.cs$") then
    return
  end
  local buf, lines = vim.fn.bufnr(fname), nil
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  else
    local ok, read = pcall(vim.fn.readfile, fname)
    if not ok then
      return
    end
    lines = read
  end
  local text = table.concat(lines, "\n")
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, "c_sharp")
  if not ok or not parser then
    return
  end

  local row = range.start.line
  local col = vim.str_byteindex(lines[row + 1] or "", encoding, range.start.character, false)
  local decl = parser:parse()[1]:root():named_descendant_for_range(row, col, row, col)
  while decl and not TYPES[decl:type()] do
    decl = decl:parent()
  end
  if not decl then
    return
  end

  local names = {}
  ---@param name TSNode?
  local function add(name)
    if name then
      names[#names + 1] = vim.treesitter.get_node_text(name, text)
    end
  end
  ---@param member TSNode
  local function accessible(member)
    local public = decl:type() == "interface_declaration"
    for child in member:iter_children() do
      if child:type() == "modifier" then
        local modifier = vim.treesitter.get_node_text(child, text)
        if modifier == "static" or modifier == "const" then
          return false
        end
        public = public or modifier == "public" or modifier == "internal"
      end
    end
    return public
  end

  local parameters = decl:type() == "record_declaration" and child_of_type(decl, "parameter_list")
  for param in parameters and parameters:iter_children() or function() end do
    if param:type() == "parameter" then
      add(param:field("name")[1])
    end
  end
  local body = child_of_type(decl, "declaration_list")
  for member in body and body:iter_children() or function() end do
    if member:type() == "property_declaration" and accessible(member) then
      add(member:field("name")[1])
    elseif member:type() == "field_declaration" and accessible(member) then
      local declaration = child_of_type(member, "variable_declaration")
      for declarator in declaration and declaration:iter_children() or function() end do
        if declarator:type() == "variable_declarator" then
          add(declarator:field("name")[1])
        end
      end
    end
  end
  return names
end

--- One level of indentation as the buffer itself uses it: the first indented
--- line. For C# that often isn't 'shiftwidth' (2 by default in LazyVim, while
--- .NET code is conventionally indented by 4).
local function indent_unit(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local indent = line:match("^(%s+)[^%s/*]")
    if indent then
      return indent
    end
  end
  return "\t"
end

---@param client vim.lsp.Client
local function position_params(client, bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  return {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = row, character = vim.str_utfindex(line, client.offset_encoding, col, false) },
  }
end

--- Members declared by the type the position refers to (see `declared_members`):
--- "textDocument/definition" when it's on a type name, "textDocument/typeDefinition"
--- when it's on a variable.
---@param client vim.lsp.Client
---@param method string
---@param callback fun(names: string[]?)
local function type_members(client, method, bufnr, row, col, callback)
  local params = position_params(client, bufnr, row, col)
  client:request(method, params, function(_, result)
    local location = result and (result[1] or result)
    callback(location and declared_members(location, client.offset_encoding))
  end, bufnr)
end

--- Settable members the initializer doesn't assign yet, per Roslyn's completion.
---@param client vim.lsp.Client
---@param initializer TSNode
---@param callback fun(names: string[]?)
local function missing_members(client, bufnr, initializer, callback)
  local brace = child_of_type(initializer, "{")
  if not brace then
    return callback(nil)
  end
  local row, col = brace:end_()
  local params = position_params(client, bufnr, row, col)
  params.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }
  client:request("textDocument/completion", params, function(_, result)
    local names = {}
    for _, item in ipairs(result and (result.items or result) or {}) do
      -- In an object initializer the list is nothing but members. Anything
      -- else means a collection initializer (`new List<int> { }`), where
      -- completion offers arbitrary expressions.
      if item.kind ~= PROPERTY and item.kind ~= FIELD then
        return callback(nil)
      end
      names[#names + 1] = item.label
    end
    callback(#names > 0 and names or nil)
  end, bufnr)
end

---@param title string
---@param members { name: string, value?: string }[]
local function action(title, params, members)
  return {
    title = title,
    kind = "refactor.rewrite",
    command = {
      title = title,
      command = COMMAND,
      arguments = { { uri = params.textDocument.uri, position = params.range.start, members = members } },
    },
  }
end

---@param params lsp.CodeActionParams
---@param callback fun(err: lsp.ResponseError?, actions: lsp.CodeAction[])
local function code_actions(params, callback)
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  local roslyn = vim.lsp.get_clients({ bufnr = bufnr, name = "roslyn" })[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, params.range.start.line, params.range.start.line + 1, false)[1] or ""
  local col = vim.str_byteindex(line, "utf-16", params.range.start.character, false)
  local creation, initializer = find_initializer(bufnr, params.range.start.line, col)
  if not roslyn or not creation or not initializer then
    return callback(nil, {})
  end

  local sources = variables_in_scope(bufnr, creation)
  local missing, order ---@type string[]?, string[]?
  local pending = #sources + 2

  local function done()
    pending = pending - 1
    if pending > 0 then
      return
    elseif not missing then
      return callback(nil, {})
    end
    -- Completion sorts alphabetically; prefer the order the type declares them in.
    local rank = {}
    for i, name in ipairs(order or {}) do
      rank[name] = i
    end
    for i, name in ipairs(missing) do
      rank[name] = rank[name] or (#(order or {}) + i)
    end
    table.sort(missing, function(a, b)
      return rank[a] < rank[b]
    end)

    local plain = vim.tbl_map(function(name)
      return { name = name }
    end, missing)
    local actions = { action("Fill object initializer", params, plain) }
    for _, source in ipairs(sources) do
      local by_lower, matched, members = {}, false, {}
      for _, name in ipairs(source.members or {}) do
        by_lower[name:lower()] = name
      end
      for _, name in ipairs(missing) do
        local match = by_lower[name:lower()]
        matched = matched or match ~= nil
        members[#members + 1] = { name = name, value = match and (source.name .. "." .. match) }
      end
      if matched then
        actions[#actions + 1] = action(("Fill object initializer from '%s'"):format(source.name), params, members)
      end
    end
    callback(nil, actions)
  end

  missing_members(roslyn, bufnr, initializer, function(names)
    missing = names
    done()
  end)
  local type = creation:field("type")[1]
  if type then
    local row, type_col = type:start()
    type_members(roslyn, "textDocument/definition", bufnr, row, type_col, function(names)
      order = names
      done()
    end)
  else
    done()
  end
  for _, source in ipairs(sources) do
    type_members(roslyn, "textDocument/typeDefinition", bufnr, source.row, source.col, function(names)
      source.members = names
      done()
    end)
  end
end

--- Inserts `Name = value,` lines into the initializer at the given position.
---@param command lsp.Command
local function fill(command)
  local args = command.arguments[1]
  local bufnr = vim.uri_to_bufnr(args.uri)
  if bufnr ~= vim.api.nvim_get_current_buf() then
    return
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, args.position.line, args.position.line + 1, false)[1] or ""
  local col = vim.str_byteindex(line, "utf-16", args.position.character, false)
  local _, initializer = find_initializer(bufnr, args.position.line, col)
  if not initializer then
    return
  end

  local open, close, last ---@type TSNode?, TSNode?, TSNode?
  for child in initializer:iter_children() do
    if child:type() == "{" then
      open = child
    elseif child:type() == "}" then
      close = child
    elseif child:type() ~= "comment" then
      last = child
    end
  end
  if not open or not close or close:missing() then
    return
  end

  local row, start_col = (last or open):end_()
  local close_row, close_col = close:start()
  local lines = { (last and last:type() ~= ",") and "," or "" }
  local tabstop = 0
  for _, member in ipairs(args.members) do
    tabstop = member.value and tabstop or tabstop + 1
    lines[#lines + 1] = ("%s = %s,"):format(member.name, member.value or ("${%d:default}"):format(tabstop))
  end

  local indent = ""
  if not last or close_row == row then
    -- `{ }` or everything on one line: put the members on lines of their own,
    -- one level deeper than the line the initializer is on, and move the `}`
    -- down below them.
    indent = indent_unit(bufnr)
    lines[#lines + 1] = ""
    local gap = vim.api.nvim_buf_get_text(bufnr, row, start_col, close_row, close_col, {})
    if table.concat(gap):match("^%s*$") then
      vim.api.nvim_buf_set_text(bufnr, row, start_col, close_row, close_col, {})
    else
      row, start_col = close_row, close_col
    end
  end
  for i = 2, #lines do
    lines[i] = lines[i] ~= "" and indent .. lines[i] or lines[i]
  end

  -- vim.snippet inserts at the cursor, which in normal mode can't sit past
  -- the last character of the line (where a trailing `{` leaves us).
  local virtualedit = vim.wo.virtualedit
  vim.wo.virtualedit = "onemore"
  vim.api.nvim_win_set_cursor(0, { row + 1, start_col })
  vim.snippet.stop()
  vim.snippet.expand(table.concat(lines, "\n"))
  vim.wo.virtualedit = virtualedit
  if tabstop == 0 then
    vim.cmd.stopinsert()
  end
end

---@type vim.lsp.Config
M.config = {
  filetypes = { "cs", "razor" },
  cmd = function(dispatchers)
    local closing = false
    return {
      request = function(method, params, callback)
        if method == "initialize" then
          callback(nil, { capabilities = { codeActionProvider = true } })
        elseif method == "textDocument/codeAction" then
          code_actions(params, callback)
        else
          callback(nil, nil)
        end
        return true, 1
      end,
      notify = function(method)
        if method == "exit" then
          closing = true
          dispatchers.on_exit(0, 0)
        end
        return true
      end,
      is_closing = function()
        return closing
      end,
      terminate = function()
        closing = true
      end,
    }
  end,
  commands = { [COMMAND] = fill },
}

return M
