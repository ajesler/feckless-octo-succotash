var storedState = localStorage.getItem('jenkins-config');
var startingState = storedState ? JSON.parse(storedState) : null;

var app = Elm.fullscreen(Elm.OptionsEditor, { getStorage: startingState });

app.ports.setStorage.subscribe(function(state) {
    localStorage.setItem('jenkins-config', JSON.stringify(state));
});