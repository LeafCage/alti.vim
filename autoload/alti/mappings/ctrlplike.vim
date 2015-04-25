if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
"=============================================================================
let g:alti#mappings#ctrlplike#define = {}
let g:alti#mappings#ctrlplike#define['PrtBS()'] = ['<BS>', '<C-]>']
let g:alti#mappings#ctrlplike#define['PrtDelete()'] = ['<Del>', '<C-d>']
let g:alti#mappings#ctrlplike#define['PrtDeleteWord()'] = ['<C-w>']
let g:alti#mappings#ctrlplike#define['PrtClear()'] = ['<C-u>']
let g:alti#mappings#ctrlplike#define['PrtInsertReg()'] = ['<C-r>', '<C-\>']
let g:alti#mappings#ctrlplike#define['PrtHistory(-1)'] = ['<C-n>']
let g:alti#mappings#ctrlplike#define['PrtSmartHistory(-1)'] = []
let g:alti#mappings#ctrlplike#define['PrtHistory(1)'] = ['<C-p>']
let g:alti#mappings#ctrlplike#define['PrtCurStart()'] = ['<C-a>']
let g:alti#mappings#ctrlplike#define['PrtCurEnd()'] = ['<C-e>']
let g:alti#mappings#ctrlplike#define['PrtCurLeft()'] = ['<C-h>', '<Left>']
let g:alti#mappings#ctrlplike#define['PrtCurRight()'] = ['<C-l>', '<Right>']
let g:alti#mappings#ctrlplike#define['PrtPage(1)'] = ['<PageDown>', '<kPageDown>']
let g:alti#mappings#ctrlplike#define['PrtPage(-1)'] = ['<PageUp>', '<kPageUp>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("j")'] = ['<C-j>', '<Down>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("k")'] = ['<C-k>', '<Up>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("t")'] = ['<Home>', '<kHome>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("b")'] = ['<End>', '<kEnd>']
let g:alti#mappings#ctrlplike#define['PrtInsertSelection()'] = ['<Tab>']
let g:alti#mappings#ctrlplike#define['PrtDetailSelection()'] = ['<C-g>']
let g:alti#mappings#ctrlplike#define['PrtExit()'] = ['<Esc>', '<C-c>']
let g:alti#mappings#ctrlplike#define['PrtSubmit()'] = ['<CR>']
let g:alti#mappings#ctrlplike#define['PrtAction("h")'] = ['<C-s>', '<C-x>', '<C-CR>']
let g:alti#mappings#ctrlplike#define['PrtAction("v")'] = ['<C-v>', '<S-CR>']
let g:alti#mappings#ctrlplike#define['ToggleType(1)'] = ['<C-f>', '<C-Down>']
let g:alti#mappings#ctrlplike#define['ToggleType(-1)'] = ['<C-b>', '<C-Up>']


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
