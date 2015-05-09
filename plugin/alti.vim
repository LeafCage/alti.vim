if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_alti')| finish| endif| let g:loaded_alti = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:alti_available = 1
if !exists('g:alti_max_history')
  let g:alti_max_history = exists('+history') ? &history : 20
end
let g:alti_config_dir = get(g:, 'alti_config_dir', '~/.config/vim/alti')
let g:alti_enable_statusline = get(g:, 'enable_statusline', 1)
let g:alti_default_mappings_base = get(g:, 'alti_default_mappings_base', 'standard')

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
