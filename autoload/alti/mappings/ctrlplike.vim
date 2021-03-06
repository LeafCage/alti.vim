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
let g:alti#mappings#ctrlplike#define['PrtPage(1)'] = ['<C-f>', '<PageDown>', '<kPageDown>']
let g:alti#mappings#ctrlplike#define['PrtPage(-1)'] = ['<C-b>', '<PageUp>', '<kPageUp>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("j")'] = ['<C-j>', '<Down>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("k")'] = ['<C-k>', '<Up>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("t")'] = ['<C-g>g', '<C-g><C-g>', '<Home>', '<kHome>']
let g:alti#mappings#ctrlplike#define['PrtSelectMove("b")'] = ['<C-g>G', '<End>', '<kEnd>']
let g:alti#mappings#ctrlplike#define['PrtInsertSelection()'] = ['<Tab>']
let g:alti#mappings#ctrlplike#define['SelectionMenu()'] = ['<C-o>']
let g:alti#mappings#ctrlplike#define['PrtExit()'] = ['<Esc>', '<C-c>']
let g:alti#mappings#ctrlplike#define['PrtSubmit()'] = ['<CR>']
let g:alti#mappings#ctrlplike#define['DefaultAction(0)'] = ['<C-y>']
let g:alti#mappings#ctrlplike#define['DefaultAction(1)'] = ['<C-v>']
let g:alti#mappings#ctrlplike#define['DefaultAction(2)'] = ['<C-t>']
let g:alti#mappings#ctrlplike#define['DefaultAction(3)'] = ['<C-z>']
let g:alti#mappings#ctrlplike#define['ToggleType(1)'] = ['<C-^>', '<C-x><C-f>', '<C-Down>']
let g:alti#mappings#ctrlplike#define['ToggleType(-1)'] = ['<C-x><C-b>', '<C-Up>']


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
