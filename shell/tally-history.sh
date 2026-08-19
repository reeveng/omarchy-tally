# A shell that has been worked in for a year answers Ctrl-R with tokens,
# hostnames and the shape of everything you run. Autosuggestion offers the same
# thing without being asked. So for the length of a stream this shell keeps its
# history somewhere else, and the somewhere else is nowhere.
#
# Source it from .zshrc or .bashrc, after the history options are set:
#
#   source ~/.config/omarchy/plugins/jmad.tally/shell/tally-history.sh
#
# The stream is a file existing, written by obs-tally-hold and deleted when the
# light goes out. Reading it is a test on every prompt and nothing more, which
# is the reason it is a file and not a question asked of OBS.
#
# What is typed while live is forgotten with the stream. A shell that was
# already open when it started keeps everything it had, waiting.

if [ -n "${ZSH_VERSION-}" ]; then

  # fc -p pushes the history onto a stack and starts an empty one; with no file
  # named, the empty one is never written anywhere. fc -P pops it and the old
  # history is back, in memory, unread from disk and unchanged on it.
  _tally_history_precmd() {
    if [[ -e ${XDG_RUNTIME_DIR:-/tmp}/obs-tally-history ]]; then
      (( ${_tally_history_held:-0} )) && return
      fc -p && _tally_history_held=1
    elif (( ${_tally_history_held:-0} )); then
      fc -P
      _tally_history_held=0
    fi
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _tally_history_precmd

elif [ -n "${BASH_VERSION-}" ]; then

  # Bash has no stack, so the history is written out, dropped, and read back at
  # the end. HISTFILE moves somewhere a reboot forgets while the stream lasts.
  _tally_history_prompt() {
    if [ -e "${XDG_RUNTIME_DIR:-/tmp}/obs-tally-history" ]; then
      [ -n "${_TALLY_HISTORY_HELD-}" ] && return
      _TALLY_HISTORY_FILE=$HISTFILE
      history -a
      history -c
      HISTFILE="${XDG_RUNTIME_DIR:-/tmp}/obs-tally-shell-history"
      _TALLY_HISTORY_HELD=1
    elif [ -n "${_TALLY_HISTORY_HELD-}" ]; then
      history -c
      rm -f -- "$HISTFILE"
      HISTFILE=$_TALLY_HISTORY_FILE
      history -r
      unset _TALLY_HISTORY_HELD
    fi
  }

  case "${PROMPT_COMMAND-}" in
  *_tally_history_prompt*) ;;
  "") PROMPT_COMMAND="_tally_history_prompt" ;;
  *) PROMPT_COMMAND="_tally_history_prompt;$PROMPT_COMMAND" ;;
  esac

fi
