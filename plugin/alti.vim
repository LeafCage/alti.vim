if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_alti')| finish| endif| let g:loaded_alti = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:alti_enable = 1
let g:alti_max_history = get(g:, 'alti_max_history', exists('+history')? &hi: 20)
let g:alti_cache_dir = get(g:, 'alti_cache_dir', '~/.cache/alti')
let g:alti_enable_statusline = get(g:, 'enable_statusline', 1)

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
