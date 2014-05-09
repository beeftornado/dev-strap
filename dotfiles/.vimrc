" Pathogen setup
execute pathogen#infect()

" Custom env settings
set number
syntax on
color grb256
" filetype plugin indent on

" NERDTree autostart
" autocmd vimenter * NERDTree

" Map nerdtree toggle command
map <C-n> :NERDTreeToggle<CR>

""""" Settings for NERDTree
let NERDTreeIgnore=['\~$', '^\.git', '\.swp$', '\.DS_Store$', '\.pyc$']
let NERDTreeShowHidden=1
" nmap <LocalLeader>nn :NERDTreeToggle<cr>

" Auto-close if the nerdtree is the only window left
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
 
" ---------------------------------------------------------------------------
"  """"" Settings for taglist.vim
let Tlist_Use_Right_Window=1
let Tlist_Auto_Open=0
let Tlist_Enable_Fold_Column=0
let Tlist_Compact_Format=0
let Tlist_WinWidth=28
let Tlist_Exit_OnlyWindow=1
let Tlist_File_Fold_Auto_Close = 1
nmap <LocalLeader>tt :Tlist<cr>

" Taglist key binding
nnoremap <silent> <C-m> :TlistToggle<CR>

"autocmd VimEnter * NERDTree
"autocmd BufEnter * NERDTreeMirror

autocmd VimEnter * wincmd w

" Powerline setup
set rtp+=/usr/local/lib/python2.7/site-packages/powerline/bindings/vim/

" Always show statusline
set laststatus=2

" Use 256 colours (Use this setting only if your terminal supports 256 colours)
set t_Co=256
