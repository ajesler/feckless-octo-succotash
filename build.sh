rm -rf extension/css/*
cp -r css extension/
rm -rf extension/images/*
cp -r images extension/

elm make BranchManager.elm --output extension/js/popup.js
elm make OptionsEditor.elm --output extension/js/options.js
