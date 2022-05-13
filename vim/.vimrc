"       _           ____   ____
"__   _(_)_ __ ___ |  _ \ / ___|
"\ \ / / | '_ ` _ \| |_) | |
" \ V /| | | | | | |  _ <| |___
"  \_/ |_|_| |_| |_|_| \_\\____|

"Delete all autocmds on reload
autocmd!
"Reload this file
command! Reload source $MYVIMRC
autocmd BufWritePost $MYVIMRC Reload

if isdirectory("/run/current-system/sw/bin")
	set shell=/run/current-system/sw/bin/bash
endif

"Auto-Install Plug
	if has("unix")
		if empty(glob($HOME.'/.vim/autoload/plug.vim'))
			!curl -fLo $HOME/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
		endif
	endif

"Plugins
	call plug#begin('$HOME/.vim/bundle')
			"Plug 'glacambre/firenvim'
			"Plug 'neoclide/coc.nvim', {'tag': '*', 'do': { -> coc#util#install()}}
			"if has("python3") | Plug 'anned20/vimsence' | endif
			Plug 'Chiel92/vim-autoformat'
			Plug 'LnL7/vim-nix'
			Plug 'PotatoesMaster/i3-vim-syntax'
			Plug 'Raimondi/delimitMate'
			Plug 'airblade/vim-gitgutter'
			Plug 'aklt/plantuml-syntax'
			Plug 'aquach/vim-http-client'
			Plug 'cespare/vim-toml'
			Plug 'dag/vim-fish'
			Plug 'dhruvasagar/vim-table-mode'
			Plug 'godlygeek/tabular'
			Plug 'itchyny/lightline.vim'
			Plug 'jamessan/vim-gnupg'
			Plug 'jreybert/vimagit'
			Plug 'junegunn/goyo.vim'
			Plug 'machakann/vim-highlightedyank'
			Plug 'mbbill/undotree'
			Plug 'mengelbrecht/lightline-bufferline'
			Plug 'ollykel/v-vim'
			Plug 'rhysd/vim-grammarous'
			Plug 'scrooloose/nerdtree'
			Plug 'tomasiser/vim-code-dark'
			Plug 'tpope/vim-commentary'
			Plug 'tpope/vim-eunuch'
			Plug 'tpope/vim-fugitive'
			Plug 'tpope/vim-surround'
			Plug 'vim-pandoc/vim-pandoc'
			Plug 'vim-pandoc/vim-pandoc-syntax'
	call plug#end()

"Colors
set t_Co=256
set t_ut=
colorscheme codedark
let g:airline_theme = 'codedark'

"Powerline/Lightline
	set laststatus=2
	set noshowmode
	let g:lightline = {
		\ 'colorscheme': 'powerline',
		\ 'active': {
		\   'left': [ [ 'mode', 'paste' ], [ 'filename', 'gitbranch', 'readonly', 'modified' ] ]
		\ },
		\ 'tabline': {
		\   'left': [['buffers']],
		\   'right': [[]]
		\ },
		\ 'component_function': {
		\   'gitbranch': 'fugitive#head',
		\   'filename':  'LightlineFilename'
		\ },
		\ 'component_expand': {
		\   'buffers': 'lightline#bufferline#buffers'
		\ },
		\ 'component_type': {
		\   'buffers': 'tabsel'
		\ },
		\ 'separator': { 'left': '', 'right': '' },
		\ 'subseparator': { 'left': '', 'right': '' },
		\ 'tabline_separator': { 'left': '', 'right': '' },
		\ 'tabline_subseparator': { 'left': '', 'right': '' }
		\}

	function! LightlineFilename()
		return &filetype ==# 'vimfiler' ? vimfiler#get_status_string() :
			\ &filetype ==# 'unite' ? unite#get_status_string() :
			\ &filetype ==# 'vimshell' ? vimshell#get_status_string() :
			\ expand('%:t') !=# '' ?
			\ substitute(substitute(expand('%'), '\(.\)\/', '\1  ', 'g'), '^\/', '/  ', '')
			\ : '[No Name]'
	endfunction

	let g:unite_force_overwrite_statusline = 0
	let g:vimfiler_force_overwrite_statusline = 0
	let g:vimshell_force_overwrite_statusline = 0

	"let g:lightline#bufferline#show_number = 2
	let g:lightline#bufferline#unicode_symbols = 1

"Misc
	set nocompatible    "Disable compatible mode
	filetype plugin on  "Enable filetype detection
	syntax on           "Always enable syntax highlighting
	set encoding=utf-8  "Always use UTF-8
	set wildmode=longest,list,full "VIM auto completion
	"Newline comments
	autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
	set splitbelow splitright "Set default split directions
	filetype plugin indent on
	set modeline        "Enable modelines
	set modelines=5
	set backspace=indent,eol,start " Make backspace work everywhere

"Spell-Check
	autocmd FileType * setlocal nospell
	set spellfile=$HOME/Dokumente/vim-spell.utf-8.add
	set spelllang=de_de,en_us

"Buffers
	set hidden
	set switchbuf=usetab,newtab
	set showtabline=2 "Always show tab line

"Line Numbers
	set number
	set relativenumber

"Tab characters
	function! AutoTab() "Use tab to indent and spaces to align
		if strpart(getline('.'), 0, col('.') - 1) =$HOME '^\s*$'
			return "\<Tab>"
		else
			return "    "
		endif
	endfunction
	imap <Tab> <C-r>=AutoTab()<CR>

	"Set a tab length of 4
	set tabstop=4
	set softtabstop=0
	set shiftwidth=4

"Show invisible characters
	set listchars=""
	"set listchars+=space:·
	"set listchars+=eol:¬
	set listchars+=tab:\|·"×
	set listchars+=trail:█
	set listchars+=extends:»
	set listchars+=precedes:«

	set list
	hi Whitespace ctermfg=DarkGray
	match Whitespace /\s/

"Delete trailing whitespaces automatically
	autocmd BufWritePre * if &syntax!="pandoc"|%s/\s\+$//e
	"autocmd BufReadPost * if &ft!="pandoc"|%s/\s\+$//e

"Windows
	if has("gui_running")
		colorscheme slate
		if has("gui_gtk2")
			set guifont=Inconsolata\ 12
		elseif has("gui_macvim")
			set guifont=Menlo\ Regular:h14
		elseif has("gui_win32") || has("gui_win64")
			set guioptions=icpM
			if (v:version == 704 && has("patch393")) || v:version > 704
				set renderoptions=type:directx,level:0.75,gamma:1.25,contrast:0.25,
					\geom:1,renmode:5,taamode:1
			endif
			set backspace=indent,eol,start
			set guifont=Ubuntu\ Mono\ derivative\ Powerlin:h13
		endif
	endif

"NERDTree
	let g:NERDTreeShowIgnoredStatus = 1
	"Auto-close vim if only NERDTree is open
	autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

"  ____                                          _
" / ___|___  _ __ ___  _ __ ___   __ _ _ __   __| |___
"| |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` / __|
"| |__| (_) | | | | | | | | | | | (_| | | | | (_| \__ \
" \____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|___/

command! -nargs=+ Compile               :term ++close ++rows=10 vimcompile.sh <args>
command! -nargs=0 MK                    :Compile mk
command! -nargs=+ Run                   :term ++rows=10 <args>

command! -nargs=+ XdgOpen               :term ++close ++hidden xdg-open <args>

command! -nargs=0 RC                    :edit $MYVIMRC

command! -nargs=0 -range Comment        :exe ":s/[^[:blank:]]/" . b:comment . "&/"
command! -nargs=0 -range UnComment      :exe ":s/" . b:comment . "//"
command! -nargs=0 -range MultiComment   :exe "'<,'>:s/[^[:blank:]]/" . b:comment . "&/"
command! -nargs=0 -range MultiUnComment :exe "'<,'>:s/" . b:comment . "//"

command! -nargs=0 QR :!qrencode -t ansiutf8 < %

" _  __          _     _           _
"| |/ /___ _   _| |__ (_)_ __   __| |___
"| ' // _ \ | | | '_ \| | '_ \ / _` / __|
"| . \  __/ |_| | |_) | | | | | (_| \__ \
"|_|\_\___|\__, |_.__/|_|_| |_|\__,_|___/
"          |___/

"Split view controls
	map <C-h> <C-w>h
	map <C-j> <C-w>j
	map <C-k> <C-w>k
	map <C-l> <C-w>l
	map <C-Left>  <C-w>h
	map <C-Down>  <C-w>j
	map <C-Up>    <C-w>k
	map <C-Right> <C-w>l

"Buffers
	map <A-left> :bp<CR>
	map <A-right> :bn<CR>
	map <C-x> :if &modified <bar> echo 'File is modified' <bar> else <bar> bp<bar>sp<bar>bn<bar>bd <bar> endif <CR>

"Copy and paste
	vnoremap <C-c> "*y :let @+=@*<CR>
	map <C-v> "+P

"Misc
	map <C-g> :Goyo \| set linebreak<CR>
	map <S-F7> :set spell!<CR>

"NERDTree
	map <C-e> :NERDTreeToggle<CR>

"Comments
	nmap <C-n> :Comment<CR>
	nmap <C-m> :UnComment<CR>
	vmap <C-n> :MultiComment<CR>
	vmap <C-m> :MultiUnComment<CR>

"Tab
	nnoremap <Tab> :s/^/\t/ <bar> :retab <CR>
	vnoremap <Tab> :s/^/\t/ <bar> :retab <CR>
	nnoremap <S-Tab> :s/^\(\t\<bar>^    \)// <CR>
	vnoremap <S-Tab> :s/^\(\t\<bar>^    \)// <CR>

"UndoTree
	nnoremap <C-r> :UndotreeToggle <CR>


" _
"| |    __ _ _ __   __ _ _   _  __ _  __ _  ___  ___
"| |   / _` | '_ \ / _` | | | |/ _` |/ _` |/ _ \/ __|
"| |__| (_| | | | | (_| | |_| | (_| | (_| |  __/\__ \
"|_____\__,_|_| |_|\__, |\__,_|\__,_|\__, |\___||___/
"                  |___/             |___/

autocmd FileType * let b:comment=&commentstring[:-3] "Should be fine for most languages

"Markdown + LaTeX
	command! -nargs=0 PandocCompile :Compile pdf.sh "%"
	command! -nargs=0 PdfOpen :XdgOpen %:r.pdf
	autocmd FileType pandoc set nofoldenable
	"autocmd FileType pandoc autocmd BufWritePost <buffer> PandocCompile

"fish
	autocmd FileType fish compiler fish
	autocmd FileType fish setlocal textwidth=79
	autocmd FileType fish setlocal nofoldenable

"Java
	command! -nargs=0 Javac :Compile javac "%"
	command! -nargs=0 JavaRun :Run java "%:r"
	command! -nargs=0 Java :Run sh -c "echo '$ javac' \\'%\\' && javac '%' && echo '$ java' \\'%:r\\' && java '%:r'"

"PlantUML
	command! -nargs=0 UmlOpen :XdgOpen %:r.png
	command! -nargs=0 Plantuml :Compile plantuml "%"
	autocmd FileType plantuml autocmd BufWritePost <buffer> Plantuml

"YAML
	autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab

if has("unix")
	if has("terminal")
		call term_start(["sh","-c", "printf 'VimRC Loaded!' && sleep 1"], {"term_finish": "close", "term_rows": 1})
	endif
endif
