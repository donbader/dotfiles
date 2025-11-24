" " Plugins will be downloaded under the specified directory.
" " You can find lots of plugins on https://vimawesome.com/
" call plug#begin('~/.vim/plugged')
"
" Plug 'morhetz/gruvbox'
" Plug 'terryma/vim-multiple-cursors'
"
" call plug#end()
"
"
" colorscheme gruvbox
" set background=dark
"
" " Display extra whitespace
" set showbreak=↪\
" set list listchars=tab:→\ ,eol:↲,nbsp:␣,trail:•,extends:⟩,precedes:⟨
" set nojoinspaces
" " Softtabs, 2 spaces
" " https://segmentfault.com/a/1190000000446738
" syntax enable
" set smarttab
" set tabstop=2
" set shiftwidth=2
" set softtabstop=2
" set shiftround
" set expandtab
" set ignorecase
" set smartcase
" set wildignorecase
" set autoindent
" set smartindent
" set mouse=a
" set enc=utf8
" set cursorline!
" set cursorcolumn
" set clipboard=unnamed
" set wrapscan
" set scrolloff=7
" set confirm
" set relativenumber
" set lazyredraw
" syntax sync minlines=256
"
" " -----------------------------
" "  Plugins
" " -----------------------------
"
" " vim-multiple-cursors
" let g:multi_cursor_exit_from_visual_mode = 0
" let g:multi_cursor_exit_from_insert_mode = 0
"
"
" " -----------------------------
" "  Number
" " -----------------------------
"
" " Set relativenumber while in normal mode
" set number
" " Invert comment below if you do/don't want auto switch relativenumber
" " set norelativenumber
" autocmd InsertEnter * :set norelativenumber
" autocmd InsertLeave * :set relativenumber
"
" " -----------------------------
" " Key mappings 
" " -----------------------------
"
" " sudo write current file
" cnoremap +w!! w !sudo tee > /dev/null %
"
" " Indent
" nnoremap < <<
" nnoremap > >>
" vnoremap < <gv
" vnoremap > >gv
"
"