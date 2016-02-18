# Jenkins Job Git Branch Manager

The projects purpose is to provide a quick way to change the git branch a Jenkins job uses.

Jenkins auth is handled by assuming you have logged into the server and the browser has access to the auth cookie.


## Usage

The extension needs a URL to the Jenkins server and a set of job names. The URL is the Jenkins root including protocol, eg https://jenkins.company.com


## Building

The extension is written in [Elm](http://elm-lang.org/), which is compiled to Javascript. In order to build this extension, you will need to have Elm installed.

`./build.sh` will populate the `extension` directory with the required files. You can the navigate to `chrome://extensions` and click "Load unpacked extension", pointing Chrome at the `extension` directory.


## Permissions

* **storage** Required to store the Jenkins URL and job names
* **https://*/** and **http://*/** Required to access the Jenkins URL


## TODO

* Formatting of Options page - Job name header missing, add job form looks janky
* Check server is accessible when the extension is loaded. Make sure no further auth required.
* Show errors when a request to read or update a branch config fails
* If no branches listed in settings, suggest adding some
* Require enter to submit on new branch name. Losing focus submits the change.
* Should not be able to set a blank branch name
* Move the Trigger Build checkbox to popup page? More likely to be used per set?
* Show build state (failed|succeeded|in progress) next to each job
* Handle jobs that are disabled on Jenkins.
    * What happens if you try to build a disabled job?


## Attributions

The extension icon is courtesy of [Jenkins](https://jenkins-ci.org/), distributed under the Creative Commons Attribution-ShareAlike 3.0 Unported
