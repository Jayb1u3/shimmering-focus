local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn

local function bufferKeymap(mode, lhs, rhs, opts)
	opts.buffer = true
	opts.silent = true
	vim.keymap.set(mode, lhs, rhs, opts)
end

--------------------------------------------------------------------------------
-- HOT-RELOADING

-- touch symlink on filechange, to trigger Obsidian's hot-reload
vim.api.nvim_create_autocmd("BufWritePost", {
	buffer = 0,
	callback = function()
		fn.system({
			"touch",
			"-h", -- touch symlink itself
			vim.env.VAULT_PATH .. "/.obsidian/themes/Shimmering Focus/theme.css",
		})
	end,
})


--------------------------------------------------------------------------------

-- never push, since build script already pushes
bufferKeymap("n", "gc", function()
	require("tinygit").smartCommit({ pushIfClean = false })
end, { desc = "󰊢 Smart-Commit (no push)" })

--------------------------------------------------------------------------------
-- COMMENT MARKS

-- goto comment marks (deferred, to override lsp-gotosymbol)
vim.defer_fn(function()
	bo.grepprg = "rg --vimgrep --no-column" -- remove columns for readability
	bufferKeymap("n", "gs", function()
		cmd([[silent! lgrep "^(  - \# <<\|/\* <)" %]]) -- riggrep-search for navigaton markers
		require("telescope.builtin").loclist({
			prompt_prefix = " ",
			prompt_title = "Navigation Markers",
			trim_text = true,
		})
	end, { desc = " Search Comment Marks" })
	-- search only for variables
	bufferKeymap("n", "gw", function()
		cmd([[silent! lgrep "^\s*--" %]]) -- riggrep-search for css variables
		require("telescope.builtin").loclist({
			prompt_prefix = "󰀫 ",
			prompt_title = "CSS Variables",
			trim_text = true,
		})
	end, { desc = " Search CSS Variables" })
end, 500)

-- next/prev comment marks
bufferKeymap(
	{ "n", "x" },
	"<C-j>",
	[[/^\/\* <<CR>:nohl<CR>]],
	{ desc = "next comment mark" }
)
bufferKeymap(
	{ "n", "x" },
	"<C-k>",
	[[?^\/\* <<CR>:nohl<CR>]],
	{ desc = "prev comment mark" }
)

-- create comment mark
bufferKeymap("n", "qw", function()
	local hr = {
		"/* ───────────────────────────────────────────────── */",
		"/* << ",
		"──────────────────────────────────────────────────── */",
		"",
		"",
	}
	fn.append(".", hr) ---@diagnostic disable-line undefined-field, param-type-mismatch
	local lineNum = vim.api.nvim_win_get_cursor(0)[1] + 2
	local colNum = #hr[2] + 2
	vim.api.nvim_win_set_cursor(0, { lineNum, colNum })
	cmd.startinsert({ bang = true })
end, { desc = " Comment Mark" })
