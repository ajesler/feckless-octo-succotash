var storedState = localStorage.getItem('jenkins-config');
var startingState = storedState ? JSON.parse(storedState) : null;

var app = Elm.fullscreen(Elm.BranchManager, { getStorage: startingState });

function focusOnBranchName() {
  var input = document.getElementById('branchName');
  if ( input != null && document.activeElement !== input ) {
    input.focus();
  }
}

setTimeout(focusOnBranchName, 50);
