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

"VIM needs a POSIX compliant shell
if &shell == '/usr/bin/fish'
	set shell=/bin/bash
endif

"Auto-Install Plug
	if empty(glob('~/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugUpdate --sync | PlugUpgrade | source $MYVIMRC
	endif

"Plugins
	call plug#begin('~/.vim/bundle')
		Plug 'airblade/vim-gitgutter'
		Plug 'aquach/vim-http-client'
		Plug 'dag/vim-fish'
		Plug 'dhruvasagar/vim-table-mode'
		Plug 'godlygeek/tabular'
		Plug 'jamessan/vim-gnupg'
		Plug 'jreybert/vimagit'
		Plug 'junegunn/goyo.vim'
		Plug 'machakann/vim-highlightedyank'
		Plug 'neoclide/coc.nvim', {'tag': '*', 'do': { -> coc#util#install()}}
		Plug 'PotatoesMaster/i3-vim-syntax'
		Plug 'Raimondi/delimitMate'
		Plug 'scrooloose/nerdtree'
		Plug 'tpope/vim-eunuch'
		Plug 'tpope/vim-fugitive'
		Plug 'vim-pandoc/vim-pandoc'
		Plug 'vim-pandoc/vim-pandoc-syntax'
		Plug 'aklt/plantuml-syntax'
	call plug#end()

"Powerline
	python from powerline.vim import setup as powerline_setup
	python powerline_setup()
	python del powerline_setup
	set rtp+=/usr/share/powerline/bindings/vim
	let g:Powerline_symbols = "fancy"
	set laststatus=2
	set noshowmode

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

"Spell-Check
autocmd FileType * setlocal nospell
set spellfile=~/Dokumente/vim-spell.utf-8.add
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
	autocmd BufWritePre * if &ft!="pandoc"|%s/\s\+$//e
	"autocmd BufReadPost * if &ft!="pandoc"|%s/\s\+$//e

"NERDTree
	let g:NERDTreeShowIgnoredStatus = 1
	"Autostart if vim is opened without file
		autocmd StdinReadPre * let s:std_in=1
		autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
	"Auto-close vim if only NERDTree is open
	autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

"  ____                                          _
" / ___|___  _ __ ___  _ __ ___   __ _ _ __   __| |___
"| |   / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` / __|
"| |__| (_) | | | | | | | | | | | (_| | | | | (_| \__ \
" \____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|___/

command! -nargs=+ Compile :term ++close ++rows=10 vimcompile.sh <args>
command! -nargs=+ Run     :term ++rows=10 <args>

command! -nargs=+ XdgOpen :term ++close ++hidden xdg-open <args>

command! -nargs=0 RC      :edit $MYVIMRC

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

" _
"| |    __ _ _ __   __ _ _   _  __ _  __ _  ___  ___
"| |   / _` | '_ \ / _` | | | |/ _` |/ _` |/ _ \/ __|
"| |__| (_| | | | | (_| | |_| | (_| | (_| |  __/\__ \
"|_____\__,_|_| |_|\__, |\__,_|\__,_|\__, |\___||___/
"                  |___/             |___/

"Markdown + LaTeX
	command! -nargs=0 Pandoc :Compile pdf.sh "%"
	command! -nargs=0 PdfOpen :XdgOpen %:r.pdf
	autocmd FileType pandoc set nofoldenable
	autocmd FileType pandoc autocmd BufWritePost <buffer> CompilePandoc

"fish
	autocmd FileType fish compiler fish
	autocmd FileType fish setlocal textwidth=79
	autocmd FileType fish setlocal foldmethod=expr

"Java
	command! -nargs=0 Javac :Compile javac "%"
	command! -nargs=0 JavaRun :Run java "%:r"
	command! -nargs=0 Java :Run sh -c "echo '$ javac' \\'%\\' && javac '%' && echo '$ java' \\'%:r\\' && java '%:r'"

"PlantUML
	autocmd FileType plantuml autocmd BufWritePost <buffer> make


call term_start(["sh","-c", "printf 'VimRC Loaded!' && sleep 1"], {"term_finish": "close", "term_rows": 1})
