-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Re-apply the "muthur" colorscheme whenever ThemeStore.qml regenerates
-- colors/muthur.lua (every preset switch in [SYS] > [LOOK]), so open
-- editors follow the desktop like alacritty and herdr do. Watches the
-- colors/ directory rather than the file: a rewrite that goes through a
-- rename would leave a file watch dead. Skipped if this instance has
-- since been switched to another colorscheme by hand.
if not vim.g.muthur_theme_watch then
  vim.g.muthur_theme_watch = true
  local uv = vim.uv or vim.loop
  local debounce = uv.new_timer()
  local watcher = uv.new_fs_event()
  watcher:start(vim.fn.stdpath("config") .. "/colors", {}, function(err, fname)
    if err or fname ~= "muthur.lua" then
      return
    end
    debounce:stop()
    debounce:start(100, 0, vim.schedule_wrap(function()
      if vim.g.colors_name == "muthur" then
        pcall(vim.cmd.colorscheme, "muthur")
      end
    end))
  end)
end
