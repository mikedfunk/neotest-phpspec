local lib = require("neotest.lib")
local async = require("neotest.async")
local logger = require("neotest.logging")
local utils = require("neotest-phpspec.utils")

---@class neotest.Adapter
---@field name string
local NeotestAdapter = { name = "neotest-phpspec" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
NeotestAdapter.root = lib.files.match_root_pattern("composer.json", "phspec.yml")

---@async
---@param file_path string
---@return boolean
function NeotestAdapter.is_test_file(file_path)
  if string.match(file_path, "vendor/") or not string.match(file_path, "spec/") then
    return false
  end
  return vim.endswith(file_path, "Spec.php")
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function NeotestAdapter.discover_positions(path)
  local query = [[
    ((class_declaration
      name: (name) @namespace.name (#match? @namespace.name "spec")
    )) @namespace.definition

    ((method_declaration
      (name) @test.name (#match? @test.name "it_")
    )) @test.definition
  ]]

  return lib.treesitter.parse_positions(path, query, {
    position_id = "require('neotest-phpspec.utils').make_test_id",
  })
end

---@return string
local function get_phpspec_cmd()
  local binary = "phpspec"

  if vim.fn.filereadable("vendor/bin/phpspec") then
    binary = "vendor/bin/phpspec"
  end

  return binary
end

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
function NeotestAdapter.build_spec(args)
  local position = args.tree:data()
  dump('POSITION')
  dump(position)
  local results_path = async.fn.tempname()

  local binary = get_phpspec_cmd()

  local file_arg = nil

  if position.type == 'test' then
    file_arg = position.id
  elseif position.name ~= 'spec' then
    file_arg = position.path
  end

  local command = vim.tbl_flatten({
    binary,
    "run",
    "--format",
    "junit",
    file_arg,
    "--",
    ">",
    results_path,
  })

  dump('POSITION 1')
  dump(position)
  dump('COMMAND')
  dump(command)
  dump('RESULTS_PATH')
  dump(results_path)

  return {
    command = command,
    context = {
      results_path = results_path,
    },
  }
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
function NeotestAdapter.results(test, result, tree)
  dump('RESULT')
  dump(result)
  -- dump('TEST')
  -- dump(test)
  -- dump('TREE')
  -- dump(tree)
  local output_file = test.context.results_path

  local ok, data = pcall(lib.files.read, output_file)
  if not ok then
    logger.error("No spec output file found:", output_file)
    return {}
  end

  local ok, parsed_data = pcall(lib.xml.parse, data)
  if not ok then
    logger.error("Failed to parse spec output:", output_file)
    return {}
  end

  local ok, results = pcall(utils.get_test_results, parsed_data, output_file)
  if not ok then
    logger.error("Could not get spec results", output_file)
    return {}
  end

  return results
end

local is_callable = function(obj)
  return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

setmetatable(NeotestAdapter, {
  __call = function(_, opts)
    if is_callable(opts.phpspec_cmd) then
      get_phpspec_cmd = opts.phpspec_cmd
    elseif opts.phpspec_cmd then
      get_phpspec_cmd = function()
        return opts.phpspec_cmd
      end
    end
    return NeotestAdapter
  end,
})

return NeotestAdapter
