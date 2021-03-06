if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
"=============================================================================
let g:alti#mappings#standard#define = {}
let g:alti#mappings#standard#define['PrtBS()'] = ['<BS>', '<C-h>']
let g:alti#mappings#standard#define['PrtDelete()'] = ['<Del>', '<C-d>']
let g:alti#mappings#standard#define['PrtDeleteWord()'] = ['<C-w>']
let g:alti#mappings#standard#define['PrtClear()'] = ['<C-u>']
let g:alti#mappings#standard#define['PrtInsertReg()'] = ['<C-r>']
let g:alti#mappings#standard#define['PrtHistory(-1)'] = ['<C-x><C-n>', '<C-_>']
let g:alti#mappings#standard#define['PrtSmartHistory(-1)'] = []
let g:alti#mappings#standard#define['PrtHistory(1)'] = ['<C-x><C-p>', '<C-s>']
let g:alti#mappings#standard#define['PrtCurStart()'] = ['<C-a>']
let g:alti#mappings#standard#define['PrtCurEnd()'] = ['<C-e>']
let g:alti#mappings#standard#define['PrtCurLeft()'] = ['<C-b>', '<Left>']
let g:alti#mappings#standard#define['PrtCurRight()'] = ['<C-f>', '<Right>']
let g:alti#mappings#standard#define['PrtPage(1)'] = ['<C-j>', '<PageDown>', '<kPageDown>']
let g:alti#mappings#standard#define['PrtPage(-1)'] = ['<C-k>', '<PageUp>', '<kPageUp>']
let g:alti#mappings#standard#define['PrtSelectMove("j")'] = ['<C-n>', '<Down>']
let g:alti#mappings#standard#define['PrtSelectMove("k")'] = ['<C-p>', '<Up>']
let g:alti#mappings#standard#define['PrtSelectMove("t")'] = ['<C-g>g', '<C-g><C-g>', '<Home>', '<kHome>']
let g:alti#mappings#standard#define['PrtSelectMove("b")'] = ['<C-g>G', '<End>', '<kEnd>']
let g:alti#mappings#standard#define['PrtInsertSelection()'] = ['<Tab>']
let g:alti#mappings#standard#define['SelectionMenu()'] = ['<C-o>']
let g:alti#mappings#standard#define['PrtExit()'] = ['<Esc>', '<C-c>']
let g:alti#mappings#standard#define['PrtSubmit()'] = ['<CR>']
let g:alti#mappings#standard#define['DefaultAction(0)'] = ['<C-y>']
let g:alti#mappings#standard#define['DefaultAction(1)'] = ['<C-v>']
let g:alti#mappings#standard#define['DefaultAction(2)'] = ['<C-t>']
let g:alti#mappings#standard#define['DefaultAction(3)'] = ['<C-z>']
let g:alti#mappings#standard#define['ToggleType(1)'] = ['<C-^>', '<C-x><C-f>', '<C-Down>']
let g:alti#mappings#standard#define['ToggleType(-1)'] = ['<C-x><C-b>', '<C-Up>']


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
