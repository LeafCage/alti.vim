if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
"=============================================================================
let g:alti#mappings#standard#define = {}
let g:alti#mappings#standard#define['PrtBS()'] = ['<BS>', '<C-h>']
let g:alti#mappings#standard#define['PrtDelete()'] = ['<Del>']
let g:alti#mappings#standard#define['PrtDeleteWord()'] = ['<C-w>']
let g:alti#mappings#standard#define['PrtClear()'] = ['<C-u>']
let g:alti#mappings#standard#define['PrtInsertReg()'] = ['<C-r>']
let g:alti#mappings#standard#define['PrtHistory(-1)'] = ['<C-x><C-n>']
let g:alti#mappings#standard#define['PrtSmartHistory(-1)'] = []
let g:alti#mappings#standard#define['PrtHistory(1)'] = ['<C-x><C-p>']
let g:alti#mappings#standard#define['PrtCurStart()'] = ['<C-a>']
let g:alti#mappings#standard#define['PrtCurEnd()'] = ['<C-e>']
let g:alti#mappings#standard#define['PrtCurLeft()'] = ['<C-b>', '<Left>']
let g:alti#mappings#standard#define['PrtCurRight()'] = ['<C-f>', '<Right>']
let g:alti#mappings#standard#define['PrtPage(1)'] = ['<C-j>', '<PageDown>', '<kPageDown>']
let g:alti#mappings#standard#define['PrtPage(-1)'] = ['<C-k>', '<PageUp>', '<kPageUp>']
let g:alti#mappings#standard#define['PrtSelectMove("j")'] = ['<C-n>', '<Down>']
let g:alti#mappings#standard#define['PrtSelectMove("k")'] = ['<C-p>', '<Up>']
let g:alti#mappings#standard#define['PrtSelectMove("t")'] = ['<Home>', '<kHome>']
let g:alti#mappings#standard#define['PrtSelectMove("b")'] = ['<End>', '<kEnd>']
let g:alti#mappings#standard#define['PrtInsertSelection()'] = ['<Tab>']
let g:alti#mappings#standard#define['PrtInsertSelection("\<Space>")'] = ['<Space>']
let g:alti#mappings#standard#define['PrtDetailSelection()'] = ['<C-g>']
let g:alti#mappings#standard#define['PrtExit()'] = ['<Esc>', '<C-c>']
let g:alti#mappings#standard#define['PrtSubmit()'] = ['<CR>']
let g:alti#mappings#standard#define['PrtAction("h")'] = ['<C-s>', '<C-CR>']
let g:alti#mappings#standard#define['PrtAction("v")'] = ['<C-v>', '<S-CR>']
let g:alti#mappings#standard#define['ToggleType(1)'] = ['<C-x><C-f>', '<C-]>', '<C-Down>']
let g:alti#mappings#standard#define['ToggleType(-1)'] = ['<C-x><C-b>', '<C-\>', '<C-Up>']


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
