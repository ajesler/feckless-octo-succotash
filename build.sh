rm -rf extension/*

cp -r assets/ extension/
cp manifest.json extension/manifest.json

elm package install

elm make src/BranchManager.elm --output extension/js/popup.js
elm make src/OptionsEditor.elm --output extension/js/options.js

echo "Package build complete in extension/"
