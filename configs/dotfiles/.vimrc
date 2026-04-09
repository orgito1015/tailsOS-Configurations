" ~/.vimrc — Vim configuration for Tails OS sessions
" Managed by tailsOS-Configurations.

" ── Security / privacy ────────────────────────────────────────────────────────
set noswapfile          " No swap files (could leak contents to disk)
set nobackup            " No backup files
set nowritebackup       " No write-backup files
set viminfo=            " Do not write .viminfo (history/mark persistence)
set history=0           " No command history in memory

" ── Encoding ──────────────────────────────────────────────────────────────────
set encoding=utf-8
set fileencoding=utf-8
scriptencoding utf-8

" ── Interface ─────────────────────────────────────────────────────────────────
set number              " Show line numbers
set relativenumber      " Relative line numbers for easy navigation
set ruler               " Show cursor position in status line
set showcmd             " Show partial command in status bar
set showmode            " Show current mode (INSERT, VISUAL…)
set cursorline          " Highlight the line under the cursor
set scrolloff=5         " Keep 5 lines above/below cursor
set sidescrolloff=5     " Keep 5 columns left/right of cursor
set laststatus=2        " Always show status line
set wildmenu            " Command-line completion with menu
set wildmode=longest,list,full

" ── Search ────────────────────────────────────────────────────────────────────
set incsearch           " Incremental search as you type
set hlsearch            " Highlight search matches
set ignorecase          " Case-insensitive search …
set smartcase           " … unless pattern contains uppercase
nnoremap <CR> :nohlsearch<CR>  " Clear search highlight with Enter

" ── Indentation ───────────────────────────────────────────────────────────────
set tabstop=4           " Tab = 4 spaces wide
set shiftwidth=4        " Auto-indent with 4 spaces
set expandtab           " Insert spaces instead of tab characters
set smartindent         " Context-aware auto-indent
set autoindent          " Copy indent from current line

" ── Line handling ─────────────────────────────────────────────────────────────
set wrap                " Wrap long lines visually (do not insert newlines)
set linebreak           " Wrap at word boundaries
set textwidth=0         " No hard line breaks on insert

" ── Mouse ─────────────────────────────────────────────────────────────────────
set mouse=a             " Enable mouse in all modes

" ── Clipboard ─────────────────────────────────────────────────────────────────
" Use system clipboard when available
if has('clipboard')
    set clipboard=unnamedplus
endif

" ── Syntax & colours ─────────────────────────────────────────────────────────
syntax enable
set background=dark

" ── Key mappings ─────────────────────────────────────────────────────────────
" Leader key
let mapleader = ","

" Quick save
nnoremap <leader>w :w<CR>

" Quick quit
nnoremap <leader>q :q<CR>

" Toggle line numbers
nnoremap <leader>n :set number! relativenumber!<CR>

" Open a shell split
nnoremap <leader>sh :split term://bash<CR>

" Navigate splits
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" ── File type detection ───────────────────────────────────────────────────────
filetype plugin indent on

" ── Trim trailing whitespace on save ─────────────────────────────────────────
autocmd BufWritePre * :%s/\s\+$//e
