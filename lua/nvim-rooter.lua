local _config = {
  patterns = {},
  manual = false,
  trigger_patterns = {},
  exclude_filetypes = {
    [''] = true,
    ['help'] = true,
    ['nofile'] = true,
    ['NvimTree'] = true,
    ['dashboard'] = true,
    ['TelescopePrompt'] = true,
  },
}

local function parent_dir(dir)
  return vim.fn.fnamemodify(dir, ':h')
end

local function change_dir(dir)
  dir = vim.fn.fnameescape(dir)
  vim.api.nvim_set_current_dir(dir)
end

local function match(dir, pattern)
  if string.sub(pattern, 1, 1) == '=' then
    return vim.fn.fnamemodify(dir, ':t') == string.sub(pattern, 2, #pattern)
  else
    return vim.fn.globpath(dir, pattern) ~= ''
  end
end

local function activate()
  if _config.manual then
    return false
  end

  if _config.exclude_filetypes[vim.bo.filetype] ~= nil then
    return false
  end

  local filename = vim.api.nvim_buf_get_name(0)
  for _, pattern in ipairs(_config.trigger_patterns) do
    -- https://riptutorial.com/lua/topic/5829/pattern-matching
    -- if filename:match(pattern) then -- should i use this or the one below?
    if vim.api.nvim_eval(string.format('"%s" =~ glob2regpat("%s")', filename, pattern)) == 1 then
      return true
    end
  end
  return false
end

local function get_root()
  -- don't need to resove sybolic links explicitly, because
  -- `nvim_buf_get_name` returns the resolved path.
  local search_dir = vim.fn.expand("%:p:h", true)
  vim.api.nvim_buf_set_var(0, 'current_dir', search_dir)

  while 1 do
    for _, pattern in ipairs(_config.patterns) do
      if match(search_dir, pattern) then
        return search_dir
      end
    end

    local parent = parent_dir(search_dir)
    if parent == search_dir then
      break
    end
    search_dir = parent
  end
  return nil
end

local function rooter()
  if not activate() then
    return
  end

  local root = vim.fn.exists('b:root_dir') == 1 and vim.api.nvim_buf_get_var(0, 'root_dir') or nil
  if root == nil then
    root = get_root()
    vim.api.nvim_buf_set_var(0, 'root_dir', root)
  end

  if root ~= nil then
    change_dir(root)
  end
end

local function rooter_toggle()
  local parent = vim.fn.exists('b:current_dir') == 1 and vim.api.nvim_buf_get_var(0, 'current_dir')
                  or parent_dir(vim.api.nvim_buf_get_name(0))
  if vim.fn.getcwd() ~= parent then
    change_dir(parent)
  else
    rooter()
  end
end

local function merge(tbl1, tbl2)
  -- Merges a "map" and a table
  -- tbl1 is considered to be the map and
  -- tbl2 is considered to be the table
  if tbl2 == nil then
    return tbl1
  end

  local res = {}
  for _, k in ipairs(tbl2) do
    res[k] = true
  end
  return vim.tbl_extend('force', tbl1, res)
end

local function setup(opts)
  opts = opts ~= nil and opts or {}
  _config.patterns = opts.rooter_patterns ~= nil and opts.rooter_patterns
    or { '.git', '.hg', '.svn' }
  _config.manual = opts.manual ~= nil and opts.manual or false
  _config.trigger_patterns = opts.trigger_patterns ~= nil and opts.trigger_patterns or { '*' }
  _config.exclude_filetypes = merge(_config.exclude_filetypes, opts.exclude_filetypes)
end

return {
  setup = setup,
  rooter = rooter,
  rooter_toggle = rooter_toggle,
}
