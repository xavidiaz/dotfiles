-- Workaround: the snacks picker strips trailing \r from `git diff` output, so
-- staging a hunk from the git diff picker (`git apply --cached`) fails for
-- files stored with CRLF in the index. Re-add the \r to the hunk lines before
-- handing the item to the original git_stage action.

---@param cwd string
---@param file string
---@return boolean
local function index_is_crlf(cwd, file)
	local out = vim.system({ "git", "ls-files", "--eol", "--", file }, { cwd = cwd, text = true }):wait()
	return out.code == 0 and out.stdout:match("^i/crlf%s") ~= nil
end

---@param diff string
---@return string
local function add_cr(diff)
	local lines = vim.split(diff, "\n", { plain = true })
	local in_hunk = false
	for i, line in ipairs(lines) do
		if line:match("^@@") then
			in_hunk = true
		elseif line:match("^diff %-%-git ") then
			in_hunk = false
		elseif in_hunk and line:match("^[ +-]") and not line:match("\r$") then
			-- A line followed by "\ No newline at end of file" has no line ending at all
			local next_line = lines[i + 1]
			if not (next_line and next_line:match("^\\")) then
				lines[i] = line .. "\r"
			end
		end
	end
	return table.concat(lines, "\n")
end

return {
	"folke/snacks.nvim",
	opts = {
		picker = {
			actions = {
				git_stage = function(picker, ...)
					for _, item in ipairs(picker:selected({ fallback = true })) do
						if item.diff and item.staged ~= nil and item.file and index_is_crlf(item.cwd, item.file) then
							item.diff = add_cr(item.diff)
						end
					end
					return require("snacks.picker.actions").git_stage(picker, ...)
				end,
			},
		},
	},
}
