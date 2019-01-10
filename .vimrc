"       _           ____   ____
"__   _(_)_ __ ___ |  _ \ / ___|
"\ \ / / | '_ ` _ \| |_) | |
" \ V /| | | | | | |  _ <| |___
"  \_/ |_|_| |_| |_|_| \_\\____|

"Auto-Install Plug
	if empty(glob('~/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
	endif

"Plugins
	call plug#begin('~/.vim/bundle')
	Plug 'junegunn/goyo.vim'
	Plug 'PotatoesMaster/i3-vim-syntax'
	Plug 'jreybert/vimagit'
	Plug 'aquach/vim-http-client'
	call plug#end()

"Powerline
	python from powerline.vim import setup as powerline_setup
	python powerline_setup()
	python del powerline_setup
	set rtp+=/usr/share/powerline/bindings/vim
	let g:Powerline_symbols = "fancy"
	set laststatus=2
	set showtabline=2 "Always show tab line
	set noshowmode

"Buffers
	map <A-left> :bp<CR>
	map <A-right> :bn<CR>
	map <C-W> :if &modified <bar> echo 'File is modified' <bar> else <bar> bp<bar>sp<bar>bn<bar>bd<bar> endif <CR>

"Misc
	set nocompatible    "Disable compatible mode
	filetype plugin on  "Enable filetype detection
	syntax on           "Always enable syntax highlighting
	set encoding=utf-8  "Always use UTF-8
	set wildmode=longest,list,full "VIM Autocompletion
	"Newline comments
	autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
	set splitbelow splitright "Set default split directions
	set hidden
	set switchbuf=usetab,newtab

"Line Numbers
	set number
	set relativenumber

"Tab characters
	function! AutoTab() "Use tab to indent and spaces to align
		if strpart(getline('.'), 0, col('.') - 1) =~ '^\s*$'
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

"Show invisibles
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


"Delete trailing whitespaces when saving
autocmd BufWritePre * %s/\s\+$//e

" _  __          _     _           _
"| |/ /___ _   _| |__ (_)_ __   __| |___
"| ' // _ \ | | | '_ \| | '_ \ / _` / __|
"| . \  __/ |_| | |_) | | | | | (_| \__ \
"|_|\_\___|\__, |_.__/|_|_| |_|\__,_|___/
"          |___/

"Split view contols
	map <C-h> <C-w>h
	map <C-j> <C-w>j
	map <C-k> <C-w>k
	map <C-l> <C-w>l
	map <C-Left>  <C-w>h
	map <C-Down>  <C-w>j
	map <C-Up>    <C-w>k
	map <C-Right> <C-w>l

"Copy and paste
	vnoremap <C-c> "*y :let @+=@*<CR>
	map <C-v> "+P

"Misc
	map <C-g> :Goyo \| set linebreak<CR>


