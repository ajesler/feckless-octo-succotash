# feckless-octo-succotash
Manage Jenkins branch configurations, via Chrome.

## Building

`./build.sh`

## TODO
* Check server is accessible when the extension is loaded. Make sure no further auth required.
* Show errors when a request to read or update a branch config fails
* Implement trigger build functionality. Option exists but doesn't do anything at the moment
* Focus on the branch name text box when popup.html is opened
* If no branches listed in settings, suggest adding some
* Require enter to submit on new branch name. Losing focus submits the change.
* What happens if you try to build a disabled job?
