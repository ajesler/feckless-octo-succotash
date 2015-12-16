ELM_PARAM_PARSING_DIR="../elm-param-parsing"
DEPENDENCY_DIR="src/dependencies"

if [ -d "$ELM_PARAM_PARSING_DIR" ]; then
  cd $ELM_PARAM_PARSING_DIR
  git pull
else
  git clone git@github.com:ajesler/elm-param-parsing.git $ELM_PARAM_PARSING_DIR
fi

if [ ! -d "$DEPENDENCY_DIR" ]; then
  mkdir -p "$DEPENDENCY_DIR"
fi

# wtf?
cp $ELM_PARAM_PARSING_DIR/src/UrlParameterParser.elm $DEPENDENCY_DIR
cp $ELM_PARAM_PARSING_DIR/src/UrlParseUtil.elm $DEPENDENCY_DIR