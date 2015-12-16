var storedState = localStorage.getItem('jenkins-config');
var startingState = storedState ? JSON.parse(storedState) : null;

var app = Elm.fullscreen(Elm.BranchManager, { getStorage: startingState });